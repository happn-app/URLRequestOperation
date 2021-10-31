/*
Copyright 2021 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation
#if canImport(os)
import os.log
#endif

import RetryingOperation



public final class URLRequestDownloadOperation<ResponseType> : RetryingOperation, URLRequestOperation, URLSessionDownloadDelegate {
	
#if DEBUG
	public let urlOperationIdentifier: Int
#else
	public let urlOperationIdentifier: UUID
#endif
	
	public let session: URLSession
	
	/**
	 The _original_ request with which the ``URLRequestDownloadOperation`` has been initialized.
	 Might be `nil` if the request was instantiated with resume data. */
	public let originalRequest: URLRequest?
	
	public let requestProcessors: [RequestProcessor]
	public let urlResponseValidators: [URLResponseValidator]
	public let resultProcessor: AnyResultProcessor<URL, ResponseType>
	public let retryProviders: [RetryProvider]
	
	public private(set) var result: Result<URLRequestOperationResult<ResponseType>, Error> {
		get {_resultQ.sync{ isCancelled ? .failure(Err.operationCancelled) : _result }}
		set {_resultQ.sync{ _result = newValue }}
	}
	private let _resultQ: DispatchQueue
	private var _result = Result<URLRequestOperationResult<ResponseType>, Error>.failure(Err.operationNotFinished)
	
	public convenience init(
		request: URLRequest, session: URLSession = .shared,
		destination: URL, moveBehavior: URLMoveResultProcessor.MoveBehavior = .failIfDestinationExists,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		retryProviders: [RetryProvider] = []
	) where ResponseType == URL {
		self.init(
			request: request, session: session,
			task: nil,
			requestProcessors: requestProcessors,
			urlResponseValidators: urlResponseValidators,
			resultProcessor: URLMoveResultProcessor(destinationURL: destination, moveBehavior: moveBehavior).erased,
			retryProviders: retryProviders
		)
	}
	
	public convenience init(
		request: URLRequest, session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		resultProcessor: AnyResultProcessor<URL, FileHandle> = URLToFileHandleResultProcessor().erased,
		retryProviders: [RetryProvider] = []
	) where ResponseType == FileHandle {
		self.init(
			request: request, session: session,
			task: nil,
			requestProcessors: requestProcessors,
			urlResponseValidators: urlResponseValidators,
			resultProcessor: resultProcessor,
			retryProviders: retryProviders
		)
	}
	
	public convenience init(
		request: URLRequest, session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		resultProcessor: AnyResultProcessor<URL, ResponseType>,
		retryProviders: [RetryProvider] = [],
		nonConvenience: Void /* Avoids an inifinite recursion in convenience init; maybe private annotation @_disfavoredOverload would do too, idk. */
	) {
		self.init(
			request: request, session: session,
			task: nil,
			requestProcessors: requestProcessors,
			urlResponseValidators: urlResponseValidators,
			resultProcessor: resultProcessor,
			retryProviders: retryProviders
		)
	}
	
	internal init(
		request: URLRequest, session: URLSession = .shared,
		task: URLSessionDownloadTask?,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		resultProcessor: AnyResultProcessor<URL, ResponseType>,
		retryProviders: [RetryProvider] = []
	) {
#if DEBUG
		self.urlOperationIdentifier = opIdQueue.sync{
			latestURLOperationIdentifier &+= 1
			return latestURLOperationIdentifier
		}
#else
		self.urlOperationIdentifier = UUID()
#endif
		self._resultQ = DispatchQueue(label: "com.happn.URLRequestOperation.Download-\(self.urlOperationIdentifier).ResultSync")
		
		self.session = session
		self.currentRequest = request
		self.originalRequest = request
		
		self.currentTask = task
		
		self.requestProcessors = requestProcessors
		self.urlResponseValidators = urlResponseValidators
		self.resultProcessor = resultProcessor
		self.retryProviders = retryProviders
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		let task = task(for: currentRequest)
		task.resume()
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override func cancelBaseOperation() {
		currentTask?.cancel()
	}
	
	/* *************************************
	   MARK: - URL Session Download Delegate
	   ************************************* */
	
#if canImport(ObjectiveC)
	public override func responds(to aSelector: Selector!) -> Bool {
		if #available(macOS 12.0, *), session.delegate?.responds(to: aSelector) ?? false {
			return true
		}
		return super.responds(to: aSelector)
	}
	
	public override func forwardingTarget(for aSelector: Selector!) -> Any? {
		if #available(macOS 12.0, *), session.delegate?.responds(to: aSelector) ?? false {
			return session.delegate
		}
		return super.forwardingTarget(for: aSelector)
	}
#endif
	
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		print("yo1: \(location) - \(FileManager.default.fileExists(atPath: location.path))")
		currentURL = location
	}

	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		print("yo2: \(error) - \(currentURL.flatMap{ FileManager.default.fileExists(atPath: $0.path) })")
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var currentRequest: URLRequest
	private var currentTask: URLSessionDownloadTask?
	
	private var currentURL: URL?
	
	/* TODO: Resume data init. */
	private func task(for request: URLRequest) -> URLSessionDownloadTask {
		let task: URLSessionDownloadTask
		if #available(macOS 12.0, *) {
			if session.delegate is URLRequestOperation {
#if canImport(os)
				Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", log: $0, type: .info, String(describing: urlOperationIdentifier)) }
#endif
				Conf.logger?.warning("Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
			}
			
			task = currentTask ?? session.downloadTask(with: currentRequest)
			task.delegate = self
		} else {
			if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
				task = currentTask ?? session.downloadTask(with: currentRequest)
				delegate.delegates.setTaskDelegate(self, forTask: task)
			} else {
				if session.delegate != nil {
					if session.delegate is URLRequestOperation {
						/* Session’s delegate is an URLRequestOperation. */
#if canImport(os)
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", log: $0, type: .info, String(describing: urlOperationIdentifier)) }}
#endif
						Conf.logger?.warning("Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
					} else {
						/* Session’s delegate is non-nil, but it’s not an URLRequestOperationSessionDelegate. */
#if canImport(os)
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Creating task for an URLRequestDownloadOperation, but session’s delegate is non-nil, and not an URLRequestOperationSessionDelegate: creating a handler-based task, which mean you won’t receive some delegate calls.", log: $0, String(describing: urlOperationIdentifier)) }}
#endif
						Conf.logger?.warning("Creating task for an URLRequestDownloadOperation, but session’s delegate is non-nil, and not an URLRequestOperationSessionDelegate: creating a handler-based task, which mean you won’t receive some delegate calls.", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
					}
				} else {
					/* Session’s delegate is nil. */
#if canImport(os)
					if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
						Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Creating task for an URLRequestDownloadOperation, but session’s delegate is nil: creating a handler-based task, which mean task metrics won’t be collected.", log: $0, String(describing: urlOperationIdentifier)) }}
#endif
					Conf.logger?.warning("Creating task for an URLRequestDownloadOperation, but session’s delegate is nil: creating a handler-based task, which mean task metrics won’t be collected.", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
				}
				assert(currentTask == nil)
				task = session.downloadTask(with: currentRequest, completionHandler: taskEnded)
			}
		}
		return task
	}
	
	private func taskEnded(url: URL?, response: URLResponse?, error: Error?) {
		if let error = error {
//			return endBaseOperation(result: .failure(error))
		}
		
		guard let response = response, let url = url else {
			/* A nil response should indicate an error, in which case error should not be nil.
			 * We still safely unwrap the error in production mode. */
			assert(error != nil)
//			return endBaseOperation(result: .failure(error ?? Err.invalidURLSessionContract))
			return
		}
		
		guard !isCancelled else {
			return baseOperationEnded()
		}
		resultProcessor.transform(source: url, urlResponse: response, handler: { result in
//			self.endBaseOperation(result: result.map{ URLRequestOperationResult(finalURLRequest: self.currentRequest, urlResponse: response, dataResponse: $0) })
		})
	}
	
}
