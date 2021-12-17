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



public final class URLRequestDataOperation<ResultType> : RetryingOperation, URLRequestOperation, URLSessionDataDelegate {
	
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
	public let urlResponseValidators: [URLResponseValidator]
	public let resultProcessor: AnyResultProcessor<Data, ResultType>
	public let retryProviders: [RetryProvider]
	
	public private(set) var result: Result<URLRequestOperationResult<ResultType>, Error> {
		get {resultQ.sync{ isCancelled ? .failure(Err.operationCancelled) : _result }}
		set {resultQ.sync{ _result = newValue }}
	}
	
	/**
	 Inits an ``URLRequestOperation``.
	 
	 If the session’s delegate is an ``URLRequestOperationSessionDelegateProxy`` (ObjC runtime only) or an ``URLRequestOperationSessionDelegate``,
	 ``URLRequestOperation`` will create an `URLSessionTask` that will use the delegate to get the data.
	 Otherwise a handler-based task will be created. */
	public init(
		request: URLRequest, session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		resultProcessor: AnyResultProcessor<Data, ResultType>,
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
		self.resultQ = DispatchQueue(label: "com.happn.URLRequestOperation.Data-\(self.urlOperationIdentifier).ResultSync")
		
		self.session = session
		self.currentRequest = request
		self.originalRequest = request
		
		self.requestProcessors = requestProcessors
		self.urlResponseValidators = urlResponseValidators
		self.resultProcessor = resultProcessor
		self.retryProviders = retryProviders
	}
	
	public convenience init(
		url: URL, headers: [String: String?] = [:], session: URLSession = .shared,
		requestProcessors: [RequestProcessor] = [],
		urlResponseValidators: [URLResponseValidator] = [],
		resultProcessor: AnyResultProcessor<Data, ResultType>,
		retryProviders: [RetryProvider] = []
	) {
		var request = URLRequest(url: url)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		self.init(
			request: request, session: session,
			requestProcessors: requestProcessors, urlResponseValidators: urlResponseValidators,
			resultProcessor: resultProcessor,
			retryProviders: retryProviders
		)
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(currentTask == nil)
		assert(currentData == nil)
		assert(currentResponse == nil)
		assert(expectedDataSize == nil)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
		runRequestProcessors(currentRequest: currentRequest, requestProcessors: requestProcessors, handler: { request in
			guard !self.isCancelled else {
				return self.baseOperationEnded()
			}
			
			self.currentRequest = request
			
			let task = self.taskForCurrentRequest()
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
	
	/* *********************************
	   MARK: - URL Session Data Delegate
	   ********************************* */
	
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
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		assert(currentData == nil)
		assert(currentResponse == nil)
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
		currentResponse = response
		if response.expectedContentLength != -1/*NSURLResponseUnknownLength*/ {
			expectedDataSize = response.expectedContentLength
		}
		
		/* We successfully got some data from the server; let’s notify the people who care about it. */
		let userInfo = self.currentRequest.url?.host.flatMap{ [OtherSuccessRetryHelper.requestSucceededNotifUserInfoHostKey: $0] }
		NotificationCenter.default.post(name: .URLRequestOperationDidSucceedURLSessionTask, object: urlOperationIdentifier, userInfo: userInfo)
		
		let error = runResponseValidators(urlResponse: response)
		guard error == nil, !isCancelled else {
			responseValidationError = error
			return completionHandler(.cancel)
		}
		
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), dataTask.delegate === self, let d = session.delegate as? URLSessionDataDelegate {
			d.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: { responseDisposition in
				switch responseDisposition {
					case .allow, .cancel, .becomeDownload, .becomeStream: ()
					@unknown default:
#if canImport(os)
						Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Unknown response disposition %ld returned for a task managed by URLRequestOperation. The operation will probably fail or never finish.", log: $0, type: .info, String(describing: self.urlOperationIdentifier), responseDisposition.rawValue) }
#endif
						Conf.logger?.warning("Unknown response disposition \(responseDisposition) returned for a task managed by URLRequestOperation. The operation will probably fail or never finish.", metadata: [LMK.operationID: "\(self.urlOperationIdentifier)"])
				}
				completionHandler(responseDisposition)
			}) ?? completionHandler(.allow)
		} else {
			completionHandler(.allow)
		}
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
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
		
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), dataTask.delegate === self {
			(session.delegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
		}
	}
	
	@available(macOS 10.11, *)
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
#warning("TODO")
//		currentTask = streamTask
//		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
//			delegate.delegates.setTaskDelegate(self, forTask: streamTask)
//		}
		
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), dataTask.delegate === self {
			(session.delegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
		}
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
#warning("TODO")
//		currentTask = downloadTask
//		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
//			delegate.delegates.setTaskDelegate(self, forTask: downloadTask)
//		}
		
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), dataTask.delegate === self {
			(session.delegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
		}
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		assert(session === self.session)
		assert(task === self.currentTask)
		assert(currentResponse != nil || error != nil)
		assert(Self.isNotFinishedOrCancelledError(result.failure))
		
		taskEnded(data: currentData, response: currentResponse, error: responseValidationError ?? error)
		responseValidationError = nil
		expectedDataSize = nil
		currentResponse = nil
		currentData = nil
		currentTask = nil
		
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *), task.delegate === self {
			(session.delegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let resultQ: DispatchQueue
	
	private var _result = Result<URLRequestOperationResult<ResultType>, Error>.failure(Err.operationNotFinished)
	
	private var currentRequest: URLRequest
	private var currentTask: URLSessionDataTask?
	
	private var currentResponse: URLResponse?
	private var responseValidationError: Error?
	private var currentData: Data?
	
	private var expectedDataSize: Int64?
	
	private func taskForCurrentRequest() -> URLSessionDataTask {
		let task: URLSessionDataTask
		if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *) {
			if session.delegate is URLRequestOperation {
#if canImport(os)
				Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", log: $0, type: .info, String(describing: urlOperationIdentifier)) }
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
							Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", log: $0, type: .info, String(describing: urlOperationIdentifier)) }}
#endif
						Conf.logger?.warning("Very weird setup of an URLSession where its delegate is an URLRequestOperation. I hope you know what you’re doing…", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
					} else {
						/* Session’s delegate is non-nil, but it’s not an URLRequestOperationSessionDelegate. */
#if canImport(os)
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Creating task for an URLRequestDataOperation, but session’s delegate is non-nil, and not an URLRequestOperationSessionDelegate: creating a handler-based task, which mean you won’t receive some delegate calls (task did receive response, did receive data and did complete at least).", log: $0, String(describing: urlOperationIdentifier)) }}
#endif
						Conf.logger?.warning("Creating task for an URLRequestDataOperation, but session’s delegate is non-nil, and not an URLRequestOperationSessionDelegate: creating a handler-based task, which mean you won’t receive some delegate calls (task did receive response, did receive data and did complete at least).", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
					}
				} else {
					/* Session’s delegate is nil. */
#if canImport(os)
					if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
						Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Creating task for an URLRequestDataOperation, but session’s delegate is nil: creating a handler-based task, which mean task metrics won’t be collected.", log: $0, String(describing: urlOperationIdentifier)) }}
#endif
					Conf.logger?.warning("Creating task for an URLRequestDataOperation, but session’s delegate is nil: creating a handler-based task, which mean task metrics won’t be collected.", metadata: [LMK.operationID: "\(urlOperationIdentifier)"])
				}
				task = session.dataTask(with: currentRequest, completionHandler: taskEndedHandler)
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
	
	private func taskEndedHandler(data: Data?, response: URLResponse?, error: Error?) {
		/* First validate the response if we have one, and we have no errors */
		if let response = response, error == nil {
			/* We successfully got some data from the server; let’s notify the people who care about it. */
			let userInfo = self.currentRequest.url?.host.flatMap{ [OtherSuccessRetryHelper.requestSucceededNotifUserInfoHostKey: $0] }
			NotificationCenter.default.post(name: .URLRequestOperationDidSucceedURLSessionTask, object: urlOperationIdentifier, userInfo: userInfo)
			taskEnded(data: data, response: response, error: runResponseValidators(urlResponse: response))
		} else {
			taskEnded(data: data, response: response, error: error)
		}
	}
	
	private func taskEnded(data: Data?, response: URLResponse?, error: Error?) {
		if let error = error {
			return endBaseOperation(result: .failure(error))
		}
		
		guard let response = response else {
			/* A nil response should indicate an error, in which case error should not be nil.
			 * We still safely unwrap the error in production mode. */
			assert(error != nil)
			return endBaseOperation(result: .failure(error ?? Err.invalidURLSessionContract))
		}
		
		/* If the response has no data, the “did receive data” delegate method is not called and our data accumulator is nil.
		 * Tested: with the handler-based version of the task, even for 204 requests, which litterally have no data, the handler is still called with an empty Data object. */
		let data = data ?? Data()
		
		guard !isCancelled else {
			return baseOperationEnded()
		}
		resultProcessor.transform(source: data, urlResponse: response, handler: { result in
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
				NotificationCenter.default.post(name: .URLRequestOperationDidSucceedOperation, object: urlOperationIdentifier, userInfo: userInfo)
			}
		}
		baseOperationEnded(retryHelpers: retryHelpers)
	}
	
}
