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



public final class URLRequestDataOperation<ResponseType> : RetryingOperation, URLRequestOperation, URLSessionDataDelegate {
	
#if DEBUG
	public let urlOperationIdentifier: Int
#else
	public let urlOperationIdentifier: UUID
#endif
	
	public let session: URLSession
	
	/**
	 The _original_ request with which the ``URLRequestOperation`` has been initialized. */
	public let originalRequest: URLRequest
	
	public let requestProcessors: [RequestProcessor]
	public let resultValidators: [ResultValidator]
	public let resultProcessor: AnyResultProcessor<Data, ResponseType>
	public let retryProviders: [RetryProvider]
	
	/* TODO: Make this thread-safe */
	public private(set) var result = Result<URLRequestOperationResult<ResponseType>, Error>.failure(Err.operationNotFinished)
	
	/**
	 Init an ``URLRequestOperation``.
	 
	 If the session’s delegate is an ``URLRequestOperationSessionDelegateProxy`` (ObjC runtime only) or an ``URLRequestOperationSessionDelegate``,
	 ``URLRequestOperation`` will create an `URLSessionTask` that will use the delegate to get the data.
	 Otherwise a handler-based task will be created. */
	public init(
		request: URLRequest, session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		resultValidators: [ResultValidator] = [],
		resultProcessor: AnyResultProcessor<Data, ResponseType>,
		retryProviders: [RetryProvider] = [],
		nonConvenience: Void /* Avoids an inifinite recursion in convenience init; maybe private annotation @_disfavoredOverload would do too, idk. */
	) {
#if DEBUG
		self.urlOperationIdentifier = opIdQueue.sync{
			latestURLOperationIdentifier &+= 1
			return latestURLOperationIdentifier
		}
#else
		self.urlOperationIdentifier = UUID()
#endif
		self.session = session
		self.currentRequest = request
		self.originalRequest = request
		
		self.requestProcessors = requestProcessors
		self.resultValidators = resultValidators
		self.resultProcessor = resultProcessor
		self.retryProviders = retryProviders
	}
	
	public convenience init(
		request: URLRequest, session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		resultValidators: [ResultValidator] = [],
		resultProcessor: AnyResultProcessor<Data, Data> = .identity(),
		retryProviders: [RetryProvider] = []
	) where ResponseType == Data {
		self.init(request: request, session: session, requestProcessors: requestProcessors, resultValidators: resultValidators, resultProcessor: resultProcessor, retryProviders: retryProviders, nonConvenience: ())
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(currentTask == nil)
		assert(currentData == nil)
		assert(currentResponse == nil)
		assert(expectedDataSize == nil)
		assert(result.failure as? URLRequestOperationError == .operationNotFinished ||
				 result.failure as? URLRequestOperationError == .operationCancelled)
		
		runRequestProcessors(currentRequest: currentRequest, requestProcessors: requestProcessors, handler: { request in
			guard !self.isCancelled else {
				self.baseOperationEnded()
				return
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
		/* TODO: If we already ended, we should not overwrite the result. */
		result = .failure(Err.operationCancelled)
		currentTask?.cancel()
	}
	
	/* *********************************
	   MARK: - URL Session Data Delegate
	   ********************************* */
	
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
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		assert(currentData == nil)
		assert(currentResponse == nil)
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(result.failure as? URLRequestOperationError == .operationNotFinished ||
				 result.failure as? URLRequestOperationError == .operationCancelled)
		
		currentResponse = response
		if response.expectedContentLength != -1/*NSURLResponseUnknownLength*/ {
			expectedDataSize = response.expectedContentLength
		}
		
		runResultValidators(data: nil, urlResponse: response, error: nil, resultValidators: resultValidators, handler: { error in
			guard error == nil, !self.isCancelled else {
				return completionHandler(.cancel)
			}
			if #available(macOS 12.0, *), let d = session.delegate as? URLSessionDataDelegate {
				d.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: { responseDisposition in
					switch responseDisposition {
						case .allow, .cancel, .becomeDownload, .becomeStream: ()
						@unknown default:
#if canImport(os)
							Conf.oslog.flatMap{ os_log("URL Op id %{public}@: Unknown response disposition %ld returned for a task managed by URLRequestOperation. The operation will probably fail or never finish.", log: $0, type: .info, String(describing: self.urlOperationIdentifier), responseDisposition.rawValue) }
#endif
							Conf.logger?.warning("Unknown response disposition \(responseDisposition) returned for a task managed by URLRequestOperation. The operation will probably fail or never finish.", metadata: [LMK.operationID: "\(self.urlOperationIdentifier)"])
					}
					completionHandler(responseDisposition)
				}) ?? completionHandler(.allow)
			} else {
				completionHandler(.allow)
			}
		})
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(result.failure as? URLRequestOperationError == .operationNotFinished ||
				 result.failure as? URLRequestOperationError == .operationCancelled)
		
		currentData?.append(data) ?? {
			var newData: Data
			if let expectedDataSize = expectedDataSize, expectedDataSize > 0 && Int64(Int(truncatingIfNeeded: expectedDataSize)) == expectedDataSize {
				newData = Data(capacity: Int(expectedDataSize /* Checked not to overflow */))
			} else {
				newData = Data()
			}
			newData.append(data)
			currentData = newData
		}()
		
		if #available(macOS 12.0, *) {
			(session.delegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
		}
	}
	
	@available(macOS 10.11, *)
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(result.failure as? URLRequestOperationError == .operationNotFinished ||
				 result.failure as? URLRequestOperationError == .operationCancelled)
		
//		currentTask = streamTask
//		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
//			delegate.delegates.setTaskDelegate(self, forTask: streamTask)
//		}
		
		if #available(macOS 12.0, *) {
			(session.delegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
		}
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(result.failure as? URLRequestOperationError == .operationNotFinished ||
				 result.failure as? URLRequestOperationError == .operationCancelled)
		
//		currentTask = downloadTask
//		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
//			delegate.delegates.setTaskDelegate(self, forTask: downloadTask)
//		}
		
		if #available(macOS 12.0, *) {
			(session.delegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
		}
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		assert(session === self.session)
		assert(task === self.currentTask)
		assert(currentResponse != nil || error != nil)
		assert(result.failure as? URLRequestOperationError == .operationNotFinished ||
				 result.failure as? URLRequestOperationError == .operationCancelled)
		
		taskEnded(data: currentData, response: currentResponse, error: error)
		expectedDataSize = nil
		currentResponse = nil
		currentData = nil
		currentTask = nil
		
		if #available(macOS 12.0, *) {
			(session.delegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var currentRequest: URLRequest
	private var currentTask: URLSessionTask?
	
	private var currentResponse: URLResponse?
	private var currentData: Data?
	
	private var expectedDataSize: Int64?
	
	private func task(for request: URLRequest) -> URLSessionDataTask {
		let task: URLSessionDataTask
		if #available(macOS 12.0, *) {
			if session.delegate is URLRequestOperation {
#if canImport(os)
				Conf.oslog.flatMap{ os_log("URL Op id %{public}@: Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", log: $0, type: .info, String(describing: urlOperationIdentifier)) }
#endif
				Conf.logger?.warning("Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
			}
			
			task = session.dataTask(with: currentRequest)
			task.delegate = self
		} else {
			if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
				task = session.dataTask(with: currentRequest)
				delegate.delegates.setTaskDelegate(self, forTask: task)
			} else {
				if session.delegate != nil {
					if session.delegate is URLRequestOperation {
						/* Session’s delegate is an URLRequestOperation. */
#if canImport(os)
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							Conf.oslog.flatMap{ os_log("URL Op id %{public}@: Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", log: $0, type: .info, String(describing: urlOperationIdentifier)) }}
#endif
						Conf.logger?.warning("Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
					} else {
						/* Session’s delegate is non-nil, but it’s not an URLRequestOperationSessionDelegate. */
#if canImport(os)
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							Conf.oslog.flatMap{ os_log("URL Op id %{public}@: Creating task for an URLRequestDataOperation, but session’s delegate is non-nil, and not an URLRequestOperationSessionDelegate: creating a handler-based task, which mean you won’t receive some delegate calls (task did receive response, did receive data and did complete).", log: $0, String(describing: urlOperationIdentifier)) }}
#endif
						Conf.logger?.warning("Creating task for an URLRequestDataOperation, but session’s delegate is non-nil, and not an URLRequestOperationSessionDelegate: creating a handler-based task, which mean you won’t receive some delegate calls (task did receive response, did receive data and did complete).", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
					}
				} else {
					/* Session’s delegate is nil. */
#if canImport(os)
					if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
						Conf.oslog.flatMap{ os_log("URL Op id %{public}@: Creating task for an URLRequestDataOperation, but session’s delegate is nil: creating a handler-based task, which mean task metrics won’t be collected.", log: $0, String(describing: urlOperationIdentifier)) }}
#endif
					Conf.logger?.warning("Creating task for an URLRequestDataOperation, but session’s delegate is nil: creating a handler-based task, which mean task metrics won’t be collected.", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
				}
				task = session.dataTask(with: currentRequest, completionHandler: taskEnded)
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
					self.endBaseOperation(result: .failure(failure))
			}
		})
	}
	
	private func runResultValidators(data: Data?, urlResponse: URLResponse, error: Error?, resultValidators: [ResultValidator], handler: @escaping (Error?) -> Void) {
		guard !isCancelled else {
			return handler(Err.operationCancelled)
		}
		
		guard let validator = resultValidators.first else {
			return handler(error)
		}
		
		validator.validate(data: data, urlResponse: urlResponse, error: error, handler: { newError in
			self.runResultValidators(data: data, urlResponse: urlResponse, error: newError, resultValidators: Array(resultValidators.dropFirst()), handler: handler)
		})
	}
	
	private func taskEnded(data: Data?, response: URLResponse?, error: Error?) {
		guard let response = response else {
			/* A nil response should indicate an error, in which case error should not be nil.
			 * We still safely unwrap the error in production mode. */
			assert(error != nil)
			return endBaseOperation(result: .failure(error ?? Err.invalidURLSessionContract))
		}
		
		/* If the response has no data, the “did receive data” delegate method is not called and our data accumulator is nil.
		 * Tested: with the handler-based version of the task, even for 204 requests, which litterally have no data, the handler is still called with an empty Data object. */
		let data = data ?? Data()
		
		runResultValidators(data: data, urlResponse: response, error: error, resultValidators: resultValidators, handler: { error in
			guard !self.isCancelled else {
				self.baseOperationEnded()
				return
			}
			self.resultProcessor.transform(source: data, urlResponse: response, handler: { result in
				self.endBaseOperation(result: result.map{ URLRequestOperationResult(finalURLRequest: self.currentRequest, urlResponse: response, dataResponse: $0) })
			})
		})
	}
	
	private func endBaseOperation(result: Result<URLRequestOperationResult<ResponseType>, Error>) {
		let retryHelpers = result.failure.flatMap{ error -> [RetryHelper]? in
			/* We use the retry helpers returned by the first retry provider that does not return nil. */
			/* The line below might do this, but it’s obscure, and I’m not sure lazy actually does what I think… */
//			retryProviders.lazy.compactMap{ $0.retryHelpers(for: currentRequest, error: error, operation: self) }.first
			for rp in retryProviders {
				if let rh = rp.retryHelpers(for: currentRequest, error: error, operation: self) {
					return rh
				}
			}
			return nil
		}
		if retryHelpers == nil {
			/* We do not retry the operation. We must set the result. */
			self.result = result
		}
		baseOperationEnded(retryHelpers: retryHelpers)
	}
	
}
