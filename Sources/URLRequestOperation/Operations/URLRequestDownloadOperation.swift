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



public final class URLRequestDownloadOperation<ResultType> : RetryingOperation, URLRequestOperation, URLSessionDownloadDelegate {
	
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
	public let resultProcessor: AnyResultProcessor<URL, ResultType>
	public let retryProviders: [RetryProvider]
	
	public private(set) var result: Result<URLRequestOperationResult<ResultType>, Error> {
		get {resultQ.sync{ isCancelled ? .failure(Err.operationCancelled) : _result }}
		set {resultQ.sync{ _result = newValue }}
	}
	/** The resume data if available. Should not be used before the operation is over. */
	public private(set) var resumeData: Data? {
		get {resultQ.sync{ _resumeData }}
		set {resultQ.sync{ _resumeData = newValue }}
	}
	
	public convenience init(
		request: URLRequest, session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		resultProcessor: AnyResultProcessor<URL, ResultType>,
		retryProviders: [RetryProvider] = []
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
		resultProcessor: AnyResultProcessor<URL, ResultType>,
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
		self.resultQ = DispatchQueue(label: "com.happn.URLRequestOperation.Download-\(self.urlOperationIdentifier).ResultSync")
		
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
		assert(currentTask == nil)
		assert(downloadStatus.isStatusWaiting)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
#warning("TODO: Properly manage resume data")
		resumeData = nil
		
		runRequestProcessors(currentRequest: currentRequest, requestProcessors: requestProcessors, handler: { request in
			guard !self.isCancelled else {
				return self.baseOperationEnded()
			}
			
			let task = self.task(for: request)
			self.currentRequest = request
			self.currentTask = task
			task.resume()
		})
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
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), session.delegate?.responds(to: aSelector) ?? false {
			return true
		}
		return super.responds(to: aSelector)
	}
	
	public override func forwardingTarget(for aSelector: Selector!) -> Any? {
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), session.delegate?.responds(to: aSelector) ?? false {
			return session.delegate
		}
		return super.forwardingTarget(for: aSelector)
	}
#endif
	
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		assert(currentResult == nil)
		assert(session === self.session)
		assert(downloadTask === self.currentTask)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
		guard let response = downloadTask.response else {
			assertionFailure("nil task’s response in urlSession(:downloadTask:didFinishDownloadingTo:)")
			currentResult = .failure(Err.invalidURLSessionContract)
			return
		}
		
		guard !isCancelled else {
			return baseOperationEnded()
		}
		
		if let error = runResponseValidators(urlResponse: response) {
			currentResult = .failure(error)
			return
		}
		downloadStatus = .success(doneResultProcessor: false, doneDidComplete: false)
		resultProcessor.transform(source: location, urlResponse: response, handler: { res in
			session.delegateQueue.addOperation{
				assert(self.currentResult == nil)
				let res = res
					.map{ URLRequestOperationResult(finalURLRequest: self.currentRequest, urlResponse: response, result: $0) }
					.mapError{ Err.resultProcessorError($0) as Error }
				guard self.downloadStatus.doingResultProcessor() else {
					self.currentResult = res
					return
				}
				self.endBaseOperation(result: res)
				assert(self.downloadStatus.isStatusWaiting)
			}
		})
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		assert(session === self.session)
		assert(task === self.currentTask)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
		if let rd = (error as NSError?)?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
			resumeData = rd
		}
		
		if error == nil {
			let userInfo = self.currentRequest.url?.host.flatMap{ [OtherSuccessRetryHelper.requestSucceededNotifUserInfoHostKey: $0] }
			NotificationCenter.default.post(name: .URLRequestOperationDidSucceedURLSessionTask, object: nil, userInfo: userInfo)
		}
		
		guard downloadStatus.doingDidComplete() else {
			guard error == nil else {
				assertionFailure("Got error \(error!) from URLSession, but was told not to finish operation from did complete!")
				return
			}
			return
		}
		
		guard !isCancelled else {
			return baseOperationEnded()
		}
		
		assert((currentResult == nil && error != nil) || (currentResult != nil && error == nil))
		endBaseOperation(result: currentResult ?? .failure(error!))
		assert(downloadStatus.isStatusWaiting)
		currentResult = nil
		currentTask = nil
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let resultQ: DispatchQueue
	
	private var _result = Result<URLRequestOperationResult<ResultType>, Error>.failure(Err.operationNotFinished)
	private var _resumeData: Data?
	
	private var currentRequest: URLRequest
	private var currentTask: URLSessionDownloadTask?
	
	private enum DownloadStatus {
		case waiting
		case success(doneResultProcessor: Bool, doneDidComplete: Bool)
		/** Returns `true` if processing should continue in did complete. */
		mutating func doingDidComplete() -> Bool {
			switch self {
				case .waiting: return true
				case .success(doneResultProcessor: let rp, doneDidComplete: let dc):
					assert(!dc, "Invalid state \(self) for download status in result processor")
					if rp {self = .waiting;                                                    return true}
					else  {self = .success(doneResultProcessor: false, doneDidComplete: true); return false}
			}
		}
		/** Returns `true` if processing should continue in result processor. */
		mutating func doingResultProcessor() -> Bool {
			switch self {
				case .waiting: assertionFailure("Invalid state \(self) for download status in result processor"); return false
				case .success(doneResultProcessor: let rp, doneDidComplete: let dc):
					assert(!rp, "Invalid state \(self) for download status in result processor")
					if dc {self = .waiting;                                                    return true}
					else  {self = .success(doneResultProcessor: true, doneDidComplete: false); return false}
			}
		}
		var isStatusWaiting: Bool {
			switch self {
				case .waiting: return true
				default:       return false
			}
		}
	}
	
	private var downloadStatus: DownloadStatus = .waiting
	private var currentResult: Result<URLRequestOperationResult<ResultType>, Error>?
	
	/* TODO: Resume data init. */
	private func task(for request: URLRequest) -> URLSessionDownloadTask {
		let task: URLSessionDownloadTask
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *) {
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
	
	/* Handler is only called in case of success */
	private func runRequestProcessors(currentRequest: URLRequest, requestProcessors: [RequestProcessor], handler: @escaping (URLRequest) -> Void) {
		guard !isCancelled else {
			return baseOperationEnded()
		}
		
		guard let processor = requestProcessors.first else {
			return handler(currentRequest)
		}
		
		processor.transform(urlRequest: currentRequest, handler: { result in
			switch result {
				case .success(let success):
					self.runRequestProcessors(currentRequest: success, requestProcessors: Array(requestProcessors.dropFirst()), handler: handler)
					
				case .failure(let failure):
					self.endBaseOperation(result: .failure(Err.requestProcessorError(failure)))
			}
		})
	}
	
	private func runResponseValidators(urlResponse: URLResponse) -> Error? {
		guard !isCancelled else {
			return Err.operationCancelled
		}
		
		for validator in urlResponseValidators {
			if let e = validator.validate(urlResponse: urlResponse) {
				return Err.responseValidatorError(e)
			}
		}
		return nil
	}
	
	private func taskEnded(url: URL?, response: URLResponse?, error: Error?) {
		if let rd = (error as NSError?)?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
			resumeData = rd
		}
		
		if let error = error {
			return endBaseOperation(result: .failure(error))
		} else {
			let userInfo = self.currentRequest.url?.host.flatMap{ [OtherSuccessRetryHelper.requestSucceededNotifUserInfoHostKey: $0] }
			NotificationCenter.default.post(name: .URLRequestOperationDidSucceedURLSessionTask, object: nil, userInfo: userInfo)
		}
		
		guard let response = response, let url = url else {
			/* A nil response or url should indicate an error, in which case error should not be nil.
			 * We still safely unwrap the error in production mode. */
			assert(error != nil)
			return endBaseOperation(result: .failure(error ?? Err.invalidURLSessionContract))
		}
		
		guard !isCancelled else {
			return baseOperationEnded()
		}
		
		resultProcessor.transform(source: url, urlResponse: response, handler: { result in
			self.endBaseOperation(
				result: result
					.map{ URLRequestOperationResult(finalURLRequest: self.currentRequest, urlResponse: response, result: $0) }
					.mapError{ Err.resultProcessorError($0) }
			)
		})
	}
	
	private func endBaseOperation(result: Result<URLRequestOperationResult<ResultType>, Error>) {
		let retryHelpers: [RetryHelper]?
		
	retryHelpersComputation:
		if let error = result.failure {
			/* We do not want to retry a cancelled operation.
			 * In theory RetryingOperation would not let us anyway, but let’s be extra cautious. */
			guard !Self.isCancelledError(error) else {
				retryHelpers = nil
				break retryHelpersComputation
			}
			
			/* See doc of retryHelpers(for:,error:,operation:) for algorithm explanation. */
			for rp in retryProviders {
				if let rh = rp.retryHelpers(for: currentRequest, error: error, operation: self) {
					retryHelpers = rh
					break retryHelpersComputation
				}
			}
			retryHelpers = nil
		} else {
			retryHelpers = nil
		}
		if retryHelpers == nil {
			/* We do not retry the operation.
			 * We must set the result, whatever it is. */
			self.result = result
			/* If the operation is successful, let’s notify the people who care about it. */
			if result.failure == nil {
				let userInfo = self.currentRequest.url?.host.flatMap{ [OtherSuccessRetryHelper.requestSucceededNotifUserInfoHostKey: $0] }
				NotificationCenter.default.post(name: .URLRequestOperationDidSucceedOperation, object: nil, userInfo: userInfo)
			}
		}
		baseOperationEnded(retryHelpers: retryHelpers)
	}
	
}
