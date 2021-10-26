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

import RetryingOperation



public protocol RetryLimiter {
	
	func canRetry(request: URLRequest, response: URLResponse, retryCount: Int) -> Bool
	
}

public protocol RetryHelperProvider {
	
	func retryHelper(for request: URLRequest) -> RetryHelper
	
}

public final class URLRequestDataOperation<ResponseType> : RetryingOperation, URLRequestOperation, URLSessionDataDelegate {
	
#if DEBUG
	public let urlOperationIdentifier: Int
#endif
	
	public let session: URLSession
	
	/**
	 The _original_ request with which the ``URLRequestOperation`` has been initialized. */
	public let originalRequest: URLRequest
	
	public private(set) var result = Result<URLRequestOperationResult<ResponseType>, Error>.failure(Err.operationNotFinished)
	
	/**
	 Init an ``URLRequestOperation``.
	 
	 If the session’s delegate is an ``URLRequestOperationSessionDelegateProxy`` (ObjC runtime only) or an ``URLRequestOperationSessionDelegate``,
	 ``URLRequestOperation`` will create an `URLSessionTask` that will use the delegate to get the data.
	 Otherwise a handler-based task will be created. */
	public init(request: URLRequest, session: URLSession = .shared) {
#if DEBUG
		self.urlOperationIdentifier = opIdQueue.sync{
			latestURLOperationIdentifier &+= 1
			return latestURLOperationIdentifier
		}
#endif
		self.session = session
		self.currentRequest = request
		self.originalRequest = request
	}
	
	public override func startBaseOperation(isRetry: Bool) {
		assert(currentTask == nil)
		assert(result.failure as? URLRequestOperationError == Err.operationNotFinished)
		
		let task: URLSessionDataTask
		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
			task = session.dataTask(with: currentRequest)
			delegate.delegates.setTaskDelegate(self, forTask: task)
		} else if session.delegate is URLRequestOperation {
			task = session.dataTask(with: currentRequest)
		} else {
			task = session.dataTask(with: currentRequest, completionHandler: taskEnded)
		}
		currentTask = task
		task.resume()
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	/* *********************************
	   MARK: - URL Session Data Delegate
	   ********************************* */
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		print("yo1")
		/* Most likely ignored */
		completionHandler(.allow)
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		print("yo2: \(data)")
	}
	
	@available(macOS 10.11, *)
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		
		currentTask = streamTask
		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
			delegate.delegates.setTaskDelegate(self, forTask: streamTask)
		}
		print("yo4")
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		assert(session === self.session)
		assert(dataTask === self.currentTask)
		
		currentTask = downloadTask
		if let delegate = session.delegate as? URLRequestOperationSessionDelegate {
			delegate.delegates.setTaskDelegate(self, forTask: downloadTask)
		}
		print("yo5")
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		assert(session === self.session)
		assert(task === self.currentTask)
		print("yo3: \(String(describing: error))")
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* Cannot be static because we’re in a generic type */
	private let idempotentHTTPMethods = Set(arrayLiteral: "GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE")
	
	private var currentRequest: URLRequest
	private var currentTask: URLSessionTask?
	
	private var currentResponse: URLResponse?
	private var currentData: Data?
	
	fileprivate func taskEnded(data: Data?, response: URLResponse?, error: Error?) {
		print("\(String(describing: data?.reduce("", { $0 + String(format: "%02x", $1) })))")
	}
	
}
