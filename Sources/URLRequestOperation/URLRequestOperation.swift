/*
 * URLRequestOperation.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 12/11/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

import AsyncOperationResult
#if !canImport(os) && canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif
import RetryingOperation



/**
An operation that launches a given `URLSessionTask` in a given `URLSession`.

This operation has mechanism to automatically retry failed tasks if needed.

Here is the detailed lifespan of an `URLRequestOperation`:
1. Init. Not much to tell here…
2. Request Launch:
   1. First, the URL is processed for running. Which means the method
      `processURLRequestForRunning` is called. This is an override point for
      subclasses if they want to prevent the request to run depending on certain
      condition, or if they want to modify the URL Request prior running it.
      
      This processing might take some time, or be expensive resource-wise, which
      is why you can specify a queue on which the processing will be done. (This
      is the `queueForProcessingURLRequestForRunning` property.)
      
      If the processing fails (returns an error), the operation will go to the
      error processing step (4) with the given error (the operation might be
      retried later depending on the error processing result).
   2. Next, the session task is created. The creation of the task and the
      behavior of the operation will differ depending on the delegate of the URL
      session given to the operation.
      - Session delegate is an instance of `URLRequestOperationSessionDelegate`:
        The task is created with `urlSessionTaskForURLRequest(_:withDelegate)`
        (which can be overridden if need be). By default, in this method, the
        session delegate is told to forward the delegate method regarding this
        specific task to the operation (the delegate of an URL session is a
        global delegate and cannot be set by task without this hack AFAIK).

        If subclasses overwrite this method and decide to work a different way
        for the delegate method, they will be responsible for receiving the data
        and treating it, then **must** call
        `urlSession(_:task:didCompleteWithError:)` when the task is done.
      - Session delegate is kind of another class of `nil`: The task is created
        with the `urlSessionTaskForURLRequest(_:,withDataCompletionHandler:,
        downloadCompletionHandler:)`.
   3. Finally the task is launched.
3. While the request is live:
   - For data tasks, when the session delegate is an instance of
     `URLRequestOperationSessionDelegate`:
     1. A URL response is received. First the method `errorForResponse(_:)` will
        check whether the response is appropriate (correct status code and mime
        type, or other pre-filters). Then the `urlResponseProcessor` will be
        called if the previous check passes. Both method can cancel the session
        task if they deem the response not worthy of continuing.
     2. Data is then received…
     3. At one point (`urlSession(_:task:didCompleteWithError:)`), the task will
        finish. `processEndOfTask(error:)` (private) is called to check what to
        do from here.
   - For data tasks, or tasks whose delegate is not of expected class, there
     will be no response processing. The next step will be when the task is
     finished: `processEndOfTask(error:)` is called.
4. Processing the end of the task (`processEndOfTask(error:)`):
   - If there is already a final error (eg. operation cancelled), the operation
     is ended here.
   - Otherwise the `computeRetryInfo(sourceError:completionHandler:)` method is
     called on the `queueForComputingRetryInfo` (computing the retry info might
     be an expensive operation). This method is reponsible for telling whether
     the operation should be retried, and after which delay. The default
     implementation will check the error. For a network lost for instance, the
     operation should be retried for idempotent HTTP requests. The delay
     respects an exponential backoff by default. Subclasses can override to
     implement their own logic and behavior.
     This is actually the most important override point for the operation.
     
     The `computeRetryInfo` method will also allow to decide whether some “early
     retrying” techniques should be setup. Or you can setup your own. There are
     two built-in retrying techniques: The `ReachabilityObserver` which will
     simply check when the network is reachable again and the `Other Success
     Observer` which will trigger a retry when another URLRequestOperation for
     the same host succeeds.
     
     If you decide to write your own “early retrying” methods, you should
     overwrite `removeObserverForEarlyRetrying()` and remove your observers in
     your implementation. Do not forget to call super!
     
     If the operation is told to be retried, when it is retried, we simply go
     back to step 2. (The URL is re-processed, etc.) */
open class URLRequestOperation : RetryingOperation, URLSessionDataDelegate, URLSessionDownloadDelegate {
	
	public enum URLRequestOperationError : Int, Error {
		case noError = 0
		case cancelled
		case unacceptableStatusCode
		case unacceptableContentType
		
		/* Both should not happen, but syntactically can. */
		case noDataFromDataTask
		case noURLFromDownloadTask
		
		case fileAlreadyExist
	}
	
	/* **********************
	   MARK: - Initial Config
	   ********************** */
	
	public struct Config {
		
		public enum DownloadBehavior {
			
			case failIfDestinationExists
			case overwriteDestination
			case findNonExistingFilenameInFolder
			
		}
		
		public let session: URLSession
		public let originalRequest: URLRequest
		
		/**
		If non-nil, a download task will be used instead of a data task, and
		the downloaded file will be moved to the given URL. If a file already
		exists at the given URL when trying to move, the operation will use the
		`downloadBehavior` variable to determine what to do. Default is to fail.
		
		The operation will try and create intermediate folders if needed to create
		the destination file.
		
		- important: When the operation is over, use the `downloadedFileURL`
		property of the operation to retrieve the actual URL of the downloaded
		file! It might differ from the URL given here. */
		public var destinationURL: URL?
		/** When destinationURL is non-nil (when a download task is used instead
		of a data task), what happen if a file already exists at the given
		destination? Default is to fail. */
		public var downloadBehavior: DownloadBehavior
		
		/**
		If >= 0, the operation won't be retried more than the given number of
		times, unless you use a subclass that resets the number of retries at
		some point.
		
		_Note_: This variable is only used by this class's implementation of
		`computeRetryInfo()`. Subclasses can overwrite this method and thus
		overwrite the given maximum number of retries. */
		public var maximumNumberOfRetries: Int
		
		/** If `true`, even non-idempotent will be retried. Use at your own risk.
		Default is `false`. */
		public var alsoRetryNonIdempotentRequests: Bool
		
		/** The queue on which the operation for processing the URL for running
		will be run. If nil, the operation won't be dispatched and will run in the
		current context. */
		public var queueForProcessingURLRequestForRunning: OperationQueue?
		
		/** The queue on which the operation for computing the retry info will be
		run. If nil, the operation won't be dispatched and will run in the current
		context. */
		public var queueForComputingRetryInfo: OperationQueue?
		
		/** If nil, no filtering is done on the status codes; only for HTTP
		operations. */
		public var acceptableStatusCodes: IndexSet?
		
		/**
		If `nil`, no filtering is done on the content type.
		
		The filtering, if done, is simplistic. _Eg._: If the acceptable content
		types contains `["application/json", "text/*"]`, only these **exact**
		content types will match. Specifically, `application/json;format=42` will
		**not** match, nor even will `text/plain`!
		
		TODO: Make a filtering that respects the [RFC 2616](https://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html)...
		
		(_Ignore; fixes comment: */_)
		
		**Note**: This parameter does NOT set the `Accept` HTTP header field of the
		given URL request. */
		public var acceptableContentTypes: Set<String>?
		
		/**
		A handler called to process an URLResponse. In any case, a "prefiltering"
		will be done with the `acceptableStatusCodes` and `acceptableContentTypes`
		properties. If these filters pass, the `urlResponseProcessor` handler will
		be called.
		
		**Warning**: For operations whose session's delegate is not a
		`URLRequestOperationSessionDelegate`, this handler is **NOT** called.
		
		_Note_: If you are writing a subclass, you should override
		`URLSession(session:, dataTask:, didReceiveResponse:, completionHandler:)`
		to handle custom URL Response processing. */
		public var urlResponseProcessor: ((_ response: URLResponse, _ completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) -> Void)?
		
		public init(
			request: URLRequest, session s: URLSession?,
			destinationURL dURL: URL? = nil, downloadBehavior dBehavior: DownloadBehavior = .failIfDestinationExists,
			maximumNumberOfRetries maxRetries: Int = -1, allowRetryingNonIdempotentRequests: Bool = false,
			queueForProcessingURLRequestForRunning qForProcessing: OperationQueue? = nil, queueForComputingRetryInfo qForRetryInfo: OperationQueue? = nil,
			acceptableStatusCodes statusCodes: IndexSet? = IndexSet(integersIn: 200..<300),
			acceptableContentTypes contentTypes: Set<String>? = nil,
			urlResponseProcessor urp: ((_ response: URLResponse, _ completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) -> Void)? = nil
		) {
			session = (s ?? .shared)
			originalRequest = request
			
			destinationURL = dURL
			downloadBehavior = dBehavior
			
			maximumNumberOfRetries = maxRetries
			alsoRetryNonIdempotentRequests = allowRetryingNonIdempotentRequests
			
			queueForProcessingURLRequestForRunning = qForProcessing
			queueForComputingRetryInfo = qForRetryInfo
			
			acceptableStatusCodes = statusCodes
			acceptableContentTypes = contentTypes
			
			urlResponseProcessor = urp
		}
		
	}
	
	public let config: Config
	
	/* **********************************
	   MARK: - Retrieve Operation Results
	   ********************************** */
	
	/** May be non-nil for successfully finished operations. */
	public private(set) var urlResponse: URLResponse?
	public var statusCode: Int? {
		return (urlResponse as? HTTPURLResponse)?.statusCode
	}
	
	/**
   Non-nil for successfully finished operations _that used a data task_. For
	HTTP operations that used a download task, use the `downloadedFileURL`
	property.
	
	Subclasses may use another type of task, in which case both `fetchedData` and
	`downloadedFileURL` might be `nil` even if the operation ended successfully
	(see the documentation of subclasses to know how to retrieve the data). */
	public private(set) var fetchedData: Data?
	
	/**
   Non-nil for successfully finished operations _that used a download task_. For
	HTTP operations that used a data task, use the `fetchedData` property.
	
	Subclasses may use another type of task, in which case both `fetchedData` and
	`downloadedFileURL` might be `nil` even if the operation ended successfully
	(see the documentation of subclasses to know how to retrieve the data). */
	public private(set) var downloadedFileURL: URL?
	
	/**
   Always `nil` if the operation ended successfully. Should not be read while
	the operation has not ended.
	
	For subclasses, the value is valid in `urlRequestOperationWillEnd()`. */
	public private(set) var finalError: Error? {
		get {return syncFinalErrorQueue.sync{ _finalError }}
		set {syncFinalErrorQueue.sync{ _finalError = newValue }}
	}
	private var _finalError: Error?
	private let syncFinalErrorQueue = DispatchQueue(label: "Sync Access and Writes to finalError in a URLRequestOperation")
	
	/**
   For information, the current or latest URL Request that was actually sent. */
	public private(set) var currentURLRequest: URLRequest
	
	/**
   For information, the date at which the latest URL Session task has been sent. */
	public private(set) var dateOfLatestTaskStart: Date?
	
	/** For debug purpose only: An arbitrary identifier for the operation. */
	public let urlOperationIdentifier: Int
	private static var latestURLOperationIdentifier = 0
	
	/* ************
	   MARK: - Init
	   ************ */
	
	public init(config c: Config) {
		config = c
		currentURLRequest = c.originalRequest
		
		URLRequestOperation.latestURLOperationIdentifier += 1
		urlOperationIdentifier = URLRequestOperation.latestURLOperationIdentifier
	}
	
	public convenience init(request: URLRequest, session: URLSession?) {
		self.init(config: Config(request: request, session: session))
	}
	
	public convenience init(request: URLRequest) {
		self.init(request: request, session: nil)
	}
	
	public convenience init(url: URL) {
		self.init(request: URLRequest(url: url))
	}
	
	deinit {
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Deiniting", log: $0, type: .debug, urlOperationIdentifier) }}
		else                                                          {NSLog("URL Op id %d: Deiniting", urlOperationIdentifier)}
	}
	
	/* **************************
	   MARK: - Retrying Operation
	   ************************** */
	
	func prepareRunningBaseOperation(isRetry: Bool) {
		if isRetry {
			#if canImport(os)
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Retrying URL Request operation with request %@", log: $0, urlOperationIdentifier, String(describing: currentURLRequest)) }}
				else                                                          {NSLog("URL Op id %d: Retrying URL Request operation with request %@", urlOperationIdentifier, String(describing: currentURLRequest))}
			#else
				NSLogString("URL Op id \(urlOperationIdentifier): Retrying URL Request operation with request \(String(describing: currentURLRequest))")
			#endif
		}
		
		if shouldIncreaseRetryNumber {currentNumberOfRetries += 1}
		shouldIncreaseRetryNumber = true
		
		assert(finalError == nil)
		assert(currentTask == nil)
		
		dataAccumulator = nil
		expectedDataSize = nil
		
		urlResponse = nil
		fetchedData = nil
		downloadedFileURL = nil
	}
	
	open override func startBaseOperation(isRetry: Bool) {
		super.startBaseOperation(isRetry: isRetry) /* Should do nothing */
		
		prepareRunningBaseOperation(isRetry: isRetry) /* Used to be a part of the RetryingOperation class :) */
		
		func createAndLaunchTask() {
			assert(currentTask == nil)
			
			#if canImport(os)
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Creating URL Session task for URL: %@", log: $0, type: .debug, urlOperationIdentifier, String(describing: currentURLRequest)) }}
				else                                                          {NSLog("URL Op id %d: Creating URL Session task for URL: %@", urlOperationIdentifier, String(describing: currentURLRequest))}
			#else
				NSLogString("URL Op id \(urlOperationIdentifier): Creating URL Session task for URL: \(String(describing: currentURLRequest))")
			#endif
			let task: URLSessionTask
			if let delegate = config.session.delegate as? URLRequestOperationSessionDelegate {
				task = urlSessionTaskForURLRequest(currentURLRequest, withDelegate: delegate)
			} else {
				task = urlSessionTaskForURLRequest(currentURLRequest, withDataCompletionHandler: { [weak self] data, response, error in
					self?.handleDataTaskCompletionFromHandler(data: data, response: response, error: error)
				}, downloadCompletionHandler: { [weak self] url, urlResponse, error in
					self?.handleDownloadTaskCompletionFromHandler(url: url, response: urlResponse, error: error)
				})
			}
			#if canImport(os)
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Starting URL Session Task for URL: %@", log: $0, urlOperationIdentifier, String(describing: currentURLRequest)) }}
				else                                                          {NSLog("URL Op id %d: Starting URL Session Task for URL: %@", urlOperationIdentifier, String(describing: currentURLRequest))}
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: URL Request HTTP body (in base64): %@", log: $0, type: .debug, urlOperationIdentifier, currentURLRequest.httpBody?.base64EncodedString() ?? "<Empty>") }}
				else                                                          {NSLog("URL Op id %d: URL Request HTTP body (in base64): %@", urlOperationIdentifier, currentURLRequest.httpBody?.base64EncodedString() ?? "<Empty>")}
			#else
				NSLogString("URL Op id \(urlOperationIdentifier): Starting URL Session Task for URL: \(String(describing: currentURLRequest))")
				NSLogString("URL Op id \(urlOperationIdentifier): URL Request HTTP body (in base64): \(currentURLRequest.httpBody?.base64EncodedString() ?? "<Empty>")")
			#endif
			assert(task.state == .suspended)
			dateOfLatestTaskStart = Date()
			currentTask = task
			
			if di.debugLogURL != nil {
				/* In debug mode, we log the start of the request. */
				let requestBody: String
				if let httpBody = currentURLRequest.httpBody {
					if let str = String(data: httpBody, encoding: .utf8) {requestBody = "s:" + str}
					else                                                 {requestBody = "b:" + httpBody.base64EncodedString()}
				} else {
					requestBody = ""
				}
				
				logDebugInfo(type: "ios_request_start", additionalInfo: [
						"request_method": currentURLRequest.httpMethod ?? "No HTTP Method...",
						"request_url":    currentURLRequest.url?.absoluteString ?? "No URL...",
						"request_body":   requestBody
					]
				)
			}
			
			task.resume()
			
			if isCancelled {
				/* To avoid race conditions where the operation would be cancelled
				 * but the task started... Worst case scenario, the task is
				 * cancelled twice, which is not a big deal. */
				task.cancel()
			}
		}
		
		#if canImport(os)
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Processing URL %@ for running…", log: $0, type: .debug, urlOperationIdentifier, String(describing: currentURLRequest)) }}
			else                                                          {NSLog("URL Op id %d: Processing URL %@ for running…", urlOperationIdentifier, String(describing: currentURLRequest))}
		#else
			NSLogString("URL Op id \(urlOperationIdentifier): Processing URL \(String(describing: currentURLRequest)) for running…")
		#endif
		let processURLBlock: () -> Void = {
			self.processURLRequestForRunning(self.currentURLRequest){ result in
				switch result {
				case .success(let newURLRequest):
					self.currentURLRequest = newURLRequest
					#if canImport(os)
						if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Done processing URL, got new URL: %@", log: $0, type: .debug, self.urlOperationIdentifier, String(describing: self.currentURLRequest)) }}
						else                                                          {NSLog("URL Op id %d: Done processing URL, got new URL: %@", self.urlOperationIdentifier, String(describing: self.currentURLRequest))}
					#else
						NSLogString("URL Op id \(self.urlOperationIdentifier): Done processing URL, got new URL: \(String(describing: self.currentURLRequest))")
					#endif
					
					createAndLaunchTask()
					
				case .error(let error):
					#if canImport(os)
						if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Got error while processing URL: %@", log: $0, type: .debug, self.urlOperationIdentifier, String(describing: error)) }}
						else                                                          {NSLog("URL Op id %d: Got error while processing URL: %@", self.urlOperationIdentifier, String(describing: error))}
					#else
						NSLogString("URL Op id \(self.urlOperationIdentifier): Got error while processing URL: \(String(describing: error))")
					#endif
					self.processEndOfTask(error: error)
				}
			}
		}
		if let queueForProcessingURLRequestForRunning = config.queueForProcessingURLRequestForRunning {queueForProcessingURLRequestForRunning.addOperation(processURLBlock)}
		else                                                                                          {processURLBlock()}
	}
	
	open override func cancelBaseOperation() {
		super.cancelBaseOperation() /* Should do nothing */
		
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Operation has been cancelled.", log: $0, urlOperationIdentifier) }}
		else                                                          {NSLog("URL Op id %d: Operation has been cancelled.", urlOperationIdentifier)}
		
		/* Setting finalError so the operation won't be retried when the current
		 * session task ends. */
		finalError = URLRequestOperationError.cancelled
		
		currentTask?.cancel()
	}
	
	/* **********************
	   MARK: - For Subclasses
	   ********************** */
	
	/* We do not use the retry count of the retrying operation (our superclass)
	 * because we offer clients the possibility to "reset" the number of retries
	 * for exponential backoff reset. */
	public private(set) var currentNumberOfRetries: Int = 0
	
	open func /*protected*/ resetNumberOfRetries() {
		shouldIncreaseRetryNumber = false
		currentNumberOfRetries = 0
	}
	
	/**
   Subclass if you want to perform modification(s) on the request before it is
	launched.
	
	“Direct” subclasses of `URLRequestOperation` don’t have to call super as it
	is guaranteed to return the original url request. Subclasses of subclasses
	should call super though (see the doc of the subclass for more info). */
	open func processURLRequestForRunning(_ originalRequest: URLRequest, handler: @escaping (AsyncOperationResult<URLRequest>) -> Void) {
		handler(.success(originalRequest))
	}
	
	/**
   Can be overridden if need be, but do not override to customize the URL
	request. Use `processURLRequestForRunning(_:handler:)` instead.
	
	The task returned must **not** be started.
	
	If you override this method, you’ll probably want to override
	`urlSessionTaskForURLRequest(withDataCompletionHandler:downloadCompletionHandler:)`.
	*/
	open func urlSessionTaskForURLRequest(_ request: URLRequest, withDelegate delegate: URLRequestOperationSessionDelegate) -> URLSessionTask {
		let task = (config.destinationURL == nil ? config.session.dataTask(with: request) : config.session.downloadTask(with: request))
		delegate.setTaskDelegate(self, forTask: task)
		return task
	}
	
	/**
	Called to create a session task when the session's delegate is not a delegate
	which can send us back the events. In this case progress is disabled and we
	must use a handler to get the results of the tasks. Which also means only
	data and download (non-background) tasks are available.
	
	Do not override to customize the URL request. Use
	`processURLRequestForRunning(_:handler:)` instead.
	
	The task returned must **not** be started, and it **must** have either the
	data completion handler or the download completion handler set (so it must be
	either a data task or a download task...).
	
	If you override this method, you’ll probably want to override
	`urlSessionTaskForURLRequest(_:withDelegate:)`.
	*/
	open func urlSessionTaskForURLRequest(_ request: URLRequest,
		withDataCompletionHandler dataCompletionHandler: @escaping (Data?, URLResponse?, Error?) -> Void,
		downloadCompletionHandler: @escaping (URL?, URLResponse?, Error?) -> Void
	) -> URLSessionTask {
		return (config.destinationURL == nil ?
			config.session.dataTask(with: request, completionHandler: dataCompletionHandler) :
			config.session.downloadTask(with: request, completionHandler: downloadCompletionHandler)
		)
	}
	
	public enum RetryMode {
		case doNotRetry
		/* If reachability is enabled, a reachability observer will be set up to
		 * force an early retry of the request when the host becomes reachable
		 * again.
		 *
		 * If other requests observer is enabled, an observer will be set up to
		 * force an early retry of the request when another request succeeded with
		 * the same host. */
		case retry(withDelay: TimeInterval, enableReachability: Bool, enableOtherRequestsObserver: Bool)
	}
	
	/**
   Used to determine if the operation should be retried, and gives an
	opportunity to update the URL request on retry. Note the request can also be
	updated before it is sent with the `processURLRequestForRunning(_:handler:)`
	method.
	
	Subclasses can override this method (and call `super` or not) to have a
	chance of customizing the retrying of the operation.
	
	The status code and content-type filtering will always have been done before
	this method is called. (And if this method is called, the filtering has
	passed.) */
	open func computeRetryInfo(sourceError error: Error?, completionHandler: @escaping (_ retryMode: RetryMode, _ newURLRequest: URLRequest, _ newError: Error?) -> Void) /* protected... */ {
		let retryMode: RetryMode
		
		if let error = error {
			/* There was an error while processing the request. Let's compute
			 * `baseOperationNeedsRetry` and `baseOperationRetryDelay`. */
			
			guard (isRequestIdempotent(currentURLRequest) || config.alsoRetryNonIdempotentRequests) && (config.maximumNumberOfRetries < 0 || currentNumberOfRetries < config.maximumNumberOfRetries) else {
				completionHandler(.doNotRetry, currentURLRequest, error)
				return
			}
			
			/* We now know the request CAN be retried (idempotent and maximum
			 * number of retries not exceeded). Should we retry? */
			
			let nsError: NSError?
			#if !os(Linux)
				nsError = (error as NSError)
			#else
				nsError = (error as? NSError)
			#endif
			switch (error as? URLRequestOperationError, nsError?.domain, nsError?.code) {
			case (_, NSURLErrorDomain?, URLError.cancelled.rawValue?): fallthrough
			case (.cancelled?, _, _):
				/* The operation has been cancelled. We do NOT retry. */
				retryMode = .doNotRetry
				
			case (.unacceptableContentType?, _, _): fallthrough
			case (.unacceptableStatusCode?, _, _):
				/* The request has been filtered out by the explicit filters in the
				 * operation. Let's not retry! */
				retryMode = .doNotRetry
				
			default:
				/* Any other error. Probably web unreachable. Let's retry! */
				retryMode = .retry(withDelay: currentExponentialBackoffTime(), enableReachability: true, enableOtherRequestsObserver: true)
				increaseExponentialBackoff()
			}
		} else {
			retryMode = .doNotRetry
		}
		
		completionHandler(retryMode, currentURLRequest, error)
	}
	
	/** Can be overridden by subclasses to be called just before the operation
	ends. Does nothing by default; calling super is a good practice though.
	
	As soon as this method returns, the whole url request operation ends.
	`finalError` can be read here.
	
	Note: There are no asynchronicity guarantees in this method. It should
	execute quickly. */
	open func urlRequestOperationWillEnd() /* protected */ {
	}
	
	/** Convenience; returns true if request is known to be idempotent. */
	public func isRequestIdempotent(_ request: URLRequest) -> Bool {
		guard let method = request.httpMethod else {
			return false
		}
		
		return idempotentHTTPMethods.contains(method)
	}
	
	/* From ancient HCRetryingHTTPOperation:
	 * This isn't a crypto system, so we don't care about mod bias, so we just
	 * calculate the random time interval by taking the random number, mod'ing it
	 * by the number of milliseconds of the delay range, and then converting that
	 * number of milliseconds to a TimeInterval. */
	
	public func exponentialBackoffTimeForIndex(_ idx: Int) -> TimeInterval {
		/* First retry is after one second; next retry is after one minute; next
		 * retry is after one hour; next retry (and all subsequent retries) is
		 * after six hours. */
		let retryDelays: [TimeInterval] = [1, 3, 60, 60 * 60, 6 * 60 * 60]
		
		let idx = max(0, min(idx, retryDelays.count - 1))
		#if swift(>=4.2)
			return TimeInterval.random(in: 0..<retryDelays[idx])
		#else
			#if !os(Linux)
				return TimeInterval(arc4random() % UInt32(retryDelays[idx] * 1000)) / 1000
			#else
				/* VERY MUCH UNSAFE RANDOM! But we don’t really care for this
				 * particular use-case. */
				return TimeInterval(random() % Int(retryDelays[idx] * 1000)) / 1000
			#endif
		#endif
	}
	
	public func currentExponentialBackoffTime() -> TimeInterval {
		return exponentialBackoffTimeForIndex(currentExponentialBackoffIndex)
	}
	
	public func increaseExponentialBackoff() {
		currentExponentialBackoffIndex += 1
	}
	
	public func resetExponentialBackoff() {
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Resetting exponential backoff index", log: $0, type: .debug, urlOperationIdentifier) }}
		else                                                          {NSLog("URL Op id %d: Resetting exponential backoff index", urlOperationIdentifier)}
		currentExponentialBackoffIndex = 0
	}
	
	/* ****************************
	   MARK: - URL Session Delegate
	   **************************** */
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		assert(dataTask === currentTask)
		#if canImport(os)
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Got URL Session response %@", log: $0, type: .debug, urlOperationIdentifier, response) }}
			else                                                          {NSLog("URL Op id %d: Got URL Session response %@", urlOperationIdentifier, response)}
		#else
			NSLogString("URL Op id \(urlOperationIdentifier): Got URL Session response \(response)")
		#endif
		
		/* If finalError is not nil, we already have a fatal error, no need to
		 * process the responses. */
		guard finalError == nil else {
			completionHandler(.cancel)
			return
		}
		
		urlResponse = response
		
		if let error = errorForResponse(response) {
			finalError = error
			completionHandler(.cancel)
			return
		}
		expectedDataSize = response.expectedContentLength
		if let urlResponseProcessor = config.urlResponseProcessor {
			urlResponseProcessor(response, completionHandler)
			return
		}
		completionHandler(.allow)
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		assert(dataTask === currentTask)
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Received data of length %d", log: $0, type: .debug, urlOperationIdentifier, data.count) }}
		else                                                          {NSLog("URL Op id %d: Received data of length %d", urlOperationIdentifier, data.count)}
		
		/* If finalError is not nil, we already have a fatal error, no need to
		 * process the responses. */
		guard finalError == nil else {return}
		
		if dataAccumulator != nil {dataAccumulator!.append(data)}
		else {
			logDebugInfo(type: "ios_first_byte", additionalInfo: nil)
			
			var nonNilDataAccumulator: Data
			if let expectedDataSize = expectedDataSize, expectedDataSize > 0 && Int64(Int(truncatingIfNeeded: expectedDataSize)) == expectedDataSize {
				nonNilDataAccumulator = Data(capacity: Int(expectedDataSize /* Checked not to overflow */))
			} else {
				nonNilDataAccumulator = Data()
			}
			nonNilDataAccumulator.append(data)
			dataAccumulator = nonNilDataAccumulator
		}
	}
	
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		assert(downloadTask === currentTask)
		#if canImport(os)
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Did finish download to URL %{public}@", log: $0, type: .debug, urlOperationIdentifier, String(describing: location)) }}
			else                                                          {NSLog("URL Op id %d: Did finish download to URL %@", urlOperationIdentifier, String(describing: location))}
		#else
			NSLogString("URL Op id \(urlOperationIdentifier): Did finish download to URL \(String(describing: location))")
		#endif
		
		/* If finalError is not nil, we already have a fatal error, no need to
		 * process the responses. */
		guard finalError == nil else {return}
		
		do    {try processDownloadedFile(url: location)}
		catch {finalError = error}
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		assert(task === currentTask)
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Finished URL Session task", log: $0, type: .debug, urlOperationIdentifier) }}
		else                                                          {NSLog("URL Op id %d: Finished URL Session task", urlOperationIdentifier)}
		logDebugInfo(type: "ios_request_end", additionalInfo: (statusCode != nil ? ["status_code": statusCode!] : nil))
		
		if finalError == nil {
			fetchedData = dataAccumulator /* If we do not have a data task, this does nothing */
			
			if di.logFetchedStrings, let fetchedData = fetchedData, let fetchDataString = String(data: fetchedData, encoding: .utf8) {
				#if canImport(os)
					if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Fetched data as string: %@", log: $0, type: .debug, urlOperationIdentifier, fetchDataString) }}
					else                                                          {NSLog("URL Op id %d: Fetched data as string: %@", urlOperationIdentifier, fetchDataString)}
				#else
					NSLogString("URL Op id \(urlOperationIdentifier): Fetched data as string: \(fetchDataString)")
				#endif
			}
		}
		dataAccumulator = nil
		
		processEndOfTask(error: error)
	}
	
	/**
   Not really a part of URL session delegate, but here to handle response from a
	task though. */
	private func handleDataTaskCompletionFromHandler(data: Data?, response: URLResponse?, error: Error?) {
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Finished URL Session data task from handler", log: $0, type: .debug, urlOperationIdentifier) }}
		else                                                          {NSLog("URL Op id %d: Finished URL Session data task from handler", urlOperationIdentifier)}
		logDebugInfo(type: "ios_request_end", additionalInfo: (statusCode != nil ? ["status_code": statusCode!] : nil))
		
		guard finalError == nil else {
			processEndOfTask(error: nil)
			return
		}
		
		urlResponse = response
		if let response = response, let responseError = errorForResponse(response) {
			/* A response error is final and unrecoverable. */
			finalError = responseError
			processEndOfTask(error: nil)
			return
		}
		
		if let error = error {
			/* There was an error completing the task. */
			processEndOfTask(error: error)
			return
		}
		
		/* When error is nil, data should not be nil. But it syntactically can! */
		if let data = data {
			fetchedData = data
		} else {
			finalError = URLRequestOperationError.noDataFromDataTask
		}
		processEndOfTask(error: nil)
	}
	
	/**
   Not really a part of URL session delegate, but here to handle response from a
	task though. */
	private func handleDownloadTaskCompletionFromHandler(url: URL?, response: URLResponse?, error: Error?) {
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Finished URL Session download task from handler", log: $0, type: .debug, urlOperationIdentifier) }}
		else                                                          {NSLog("URL Op id %d: Finished URL Session download task from handler", urlOperationIdentifier)}
		logDebugInfo(type: "ios_request_end", additionalInfo: (statusCode != nil ? ["status_code": statusCode!] : nil))
		
		guard finalError == nil else {
			processEndOfTask(error: nil)
			return
		}
		
		urlResponse = response
		if let response = response, let responseError = errorForResponse(response) {
			/* A response error is final and unrecoverable. */
			finalError = responseError
			processEndOfTask(error: nil)
			return
		}
		
		if let error = error {
			/* There was an error completing the task. */
			processEndOfTask(error: error)
			return
		}
		
		/* When error is nil, url should not be nil. But it syntactically can! */
		if let url = url {
			do    {try processDownloadedFile(url: url)}
			catch {finalError = error}
		} else {
			finalError = URLRequestOperationError.noURLFromDownloadTask
		}
		processEndOfTask(error: nil)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	/* PATCH is **not** required to be idempotent by the standards. */
	private let idempotentHTTPMethods = Set(arrayLiteral: "GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE")
	
	private var currentTask: URLSessionTask?
	
	private var expectedDataSize: Int64?
	private var dataAccumulator: Data?
	
	private var shouldIncreaseRetryNumber = false
	
	private var currentExponentialBackoffIndex = 0
	
	private static let requestSucceededNotifUserInfoHostKey = "Host"
	
	private func errorForResponse(_ response: URLResponse) -> Error? {
		if let acceptableContentTypes = config.acceptableContentTypes {
			guard let mime = response.mimeType, acceptableContentTypes.contains(mime) else {
				return URLRequestOperationError.unacceptableContentType
			}
		}
		if let acceptableStatusCodes = config.acceptableStatusCodes {
			guard let statusCode = (response as? HTTPURLResponse)?.statusCode, acceptableStatusCodes.contains(statusCode) else {
				return URLRequestOperationError.unacceptableStatusCode
			}
		}
		return nil
	}
	
	private final func processDownloadedFile(url: URL) throws {
		let fm = FileManager.default
		var destinationURL = config.destinationURL!.absoluteURL
		let destinationFolderURL = destinationURL.deletingLastPathComponent()
		
		try fm.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
		
		if fm.fileExists(atPath: destinationURL.path) {
			switch config.downloadBehavior {
			case .failIfDestinationExists:
				throw URLRequestOperationError.fileAlreadyExist
				
			case .overwriteDestination:
				try fm.removeItem(at: destinationURL)
				
			case .findNonExistingFilenameInFolder:
				var i = 1
				let ext = destinationURL.pathExtension
				let extWithDot = (ext.isEmpty ? "" : "." + ext)
				let basename = destinationURL.deletingPathExtension().lastPathComponent
				repeat {
					i += 1
					let newBasename = basename + "-" + String(i) + extWithDot
					if #available(OSX 10.11, iOS 9.0, *) {destinationURL = URL(fileURLWithPath: newBasename, isDirectory: false, relativeTo: destinationFolderURL).absoluteURL}
					else                                 {destinationURL = destinationFolderURL.appendingPathComponent(newBasename).absoluteURL}
				} while fm.fileExists(atPath: destinationURL.path)
			}
		}
		
		try fm.moveItem(at: url, to: destinationURL)
	}
	
	private final func processEndOfTask(error: Error?) {
		currentTask = nil
		
		guard finalError == nil else {
			/* If finalError != nil, we know the task must not be retried. It is
			 * most likely cancelled, or an unrecoverable error occurred. */
			#if canImport(os)
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: URL operation finished with unrecoverable error (not retrying) %@.", log: $0, type: .debug, urlOperationIdentifier, String(describing: finalError)) }}
				else                                                          {NSLog("URL Op id %d: URL operation finished with unrecoverable error (not retrying) %@.", urlOperationIdentifier, String(describing: finalError))}
			#else
				NSLogString("URL Op id \(urlOperationIdentifier): URL operation finished with unrecoverable error (not retrying) \(String(describing: finalError)).")
			#endif
			urlRequestOperationWillEnd()
			baseOperationEnded()
			return
		}
		
		let computeRetryInfoBlock: () -> Void = {
			self.computeRetryInfo(sourceError: error) { retryMode, newURLRequest, newError in
				if newError == nil {
					/* Let's tell the world we successfully finished a URL task! */
					let userInfo = self.currentURLRequest.url?.host.flatMap{ [URLRequestOperation.requestSucceededNotifUserInfoHostKey: $0] }
					NotificationCenter.default.post(name: .URLRequestOperationDidSucceedOperation, object: nil, userInfo: userInfo)
				}
				
				switch retryMode {
				case .doNotRetry:
					#if canImport(os)
						if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: URL operation finished (not retrying) with error %@.", log: $0, type: .debug, self.urlOperationIdentifier, String(describing: newError)) }}
						else                                                          {NSLog("URL Op id %d: URL operation finished (not retrying) with error %@.", self.urlOperationIdentifier, String(describing: newError))}
					#else
						NSLogString("URL Op id \(self.urlOperationIdentifier): URL operation finished (not retrying) with error \(String(describing: newError)).")
					#endif
					self.finalError = newError
					self.urlRequestOperationWillEnd()
					self.baseOperationEnded()
					
				case .retry(let delay, let setupReachability, let setupOtherSuccessObserver):
					self.currentURLRequest = newURLRequest
					
					#if canImport(os)
						if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: URL operation finished (retrying in %g seconds) with error %@.", log: $0, type: .debug, self.urlOperationIdentifier, delay, String(describing: newError)) }}
						else                                                          {NSLog("URL Op id %d: URL operation finished (retrying in %g seconds) with error %@.", self.urlOperationIdentifier, delay, String(describing: newError))}
					#else
						NSLogString("URL Op id \(self.urlOperationIdentifier): URL operation finished (retrying in \(delay) seconds) with error \(String(describing: newError)).")
					#endif
					
					let host = self.currentURLRequest.url?.host
					#if canImport(SystemConfiguration)
						let retryHelpers: [RetryHelper?] = [
							setupOtherSuccessObserver ? OtherSuccessRetryHelper(host: host, operation: self) : nil,
							setupReachability ? ReachabilityRetryHelper(host: host, operation: self) : nil,
							TimerRetryHelper(retryDelay: delay, retryingOperation: self)
						]
					#else
						if setupReachability {
							if #available(watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Asked to setup reachability for a retry, but reachability observing is not supported on this platform.", log: $0, type: .debug, self.urlOperationIdentifier) }}
							else                          {NSLog("URL Op id %d: Asked to setup reachability for a retry, but reachability observing is not supported on this platform.", self.urlOperationIdentifier)}
						}
						let retryHelpers: [RetryHelper?] = [
							setupOtherSuccessObserver ? OtherSuccessRetryHelper(host: host, operation: self) : nil,
							TimerRetryHelper(retryDelay: delay, retryingOperation: self)
						]
					#endif
					
					self.baseOperationEnded(retryHelpers: retryHelpers.compactMap{ $0 })
				}
			}
		}
		if let queueForComputingRetryInfo = config.queueForComputingRetryInfo {queueForComputingRetryInfo.addOperation(computeRetryInfoBlock)}
		else                                                                  {computeRetryInfoBlock()}
	}
	
	public final override var isAsynchronous: Bool {
		return true
	}
	
	#if canImport(SystemConfiguration)
	private class ReachabilityRetryHelper : NSObject, RetryHelper, ReachabilitySubscriber {
		
		init?(host: String?, operation op: URLRequestOperation) {
			guard let host = host, let o = try? ReachabilityObserver.reachabilityObserver(forHost: host) else {return nil}
			operation = op
			observer = o
		}
		
		func setup() {
			/* In theory we're supposed to create the reachability observer here
			 * instead of directly when initing the object (the observer cannot be
			 * told to wait until a given moment for starting observing the
			 * reachability). Anyway we know at 99.99999% the setup will be started
			 * promply after initing the helper... */
			observer.add(subscriber: self)
		}
		
		func teardown() {
			observer.remove(subscriber: self)
		}
		
		func reachabilityDidBecomeReachable(observer: ReachabilityObserver) {
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: The reachability observer tells me the host is reachable again. Let’s force retrying the operation sooner.", log: $0, type: .debug, operation.urlOperationIdentifier) }}
			else                                                          {NSLog("URL Op id %d: The reachability observer tells me the host is reachable again. Let’s force retrying the operation sooner.", operation.urlOperationIdentifier)}
			operation.retry(in: operation.exponentialBackoffTimeForIndex(1))
		}
		
		private let observer: ReachabilityObserver
		private let operation: URLRequestOperation
		
	}
	#endif
	
	private class OtherSuccessRetryHelper : RetryHelper {
		
		init?(host h: String?, operation op: URLRequestOperation) {
			guard let h = h else {return nil}
			operation = op
			host = h
		}
		
		func setup() {
			assert(otherSuccessObserver == nil)
			otherSuccessObserver = NotificationCenter.default.addObserver(forName: .URLRequestOperationDidSucceedOperation, object: nil, queue: nil) { notif in
				let succeededHost = notif.userInfo?[URLRequestOperation.requestSucceededNotifUserInfoHostKey] as? String
				guard succeededHost == self.host else {return}
				
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Got an URL operation succeeded with same host as me. Forcing retrying sooner.", log: $0, type: .debug, self.operation.urlOperationIdentifier) }}
				else                                                          {NSLog("URL Op id %d: Got an URL operation succeeded with same host as me. Forcing retrying sooner.", self.operation.urlOperationIdentifier)}
				self.operation.retry(in: self.operation.exponentialBackoffTimeForIndex(1))
			}
		}
		
		func teardown() {
			NotificationCenter.default.removeObserver(otherSuccessObserver! /* Internal error if observer is nil... */, name: .URLRequestOperationDidSucceedOperation, object: nil)
			otherSuccessObserver = nil
		}
		
		private let host: String
		private let operation: URLRequestOperation
		private var otherSuccessObserver: NSObjectProtocol?
		
	}
	
	/* Default keys are "type", "host", "headers", "date" and "timestamp" */
	private func logDebugInfo(type: String, additionalInfo: [String: Any]?) {
		guard let url = di.debugLogURL else {return}
		
		let dateStr: String
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withFullDate, .withFullTime]
			dateStr = dateFormatter.string(from: Date())
		} else {
			/* Found here: https://stackoverflow.com/a/28016692/1152894 */
			let dateFormatter = DateFormatter()
			dateFormatter.calendar = Calendar(identifier: .iso8601)
			dateFormatter.locale = Locale(identifier: "en_US_POSIX")
			dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
			dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
			dateStr = dateFormatter.string(from: Date())
		}
		
		var tv = timeval()
		gettimeofday(&tv, nil)
		var sentData: [String: Any] = [
			"type":      type,
			"host":      currentURLRequest.url?.host ?? "Unknown",
			"headers":   currentURLRequest.allHTTPHeaderFields ?? [:],
			"date":      dateStr,
			"timestamp": NSNumber(value: 1000000 * Int64(tv.tv_sec) + Int64(tv.tv_usec))
		]
		if let additionalInfo = additionalInfo {
			for (key, val) in additionalInfo {sentData[key] = val}
		}
		
		do {
			let jsonData = try JSONSerialization.data(withJSONObject: sentData, options: [])
			if let fh = try? FileHandle(forWritingTo: url) {
				defer {fh.closeFile()}
				fh.seekToEndOfFile()
				fh.write(jsonData)
			} else {
				try jsonData.write(to: url, options: .atomic)
			}
		} catch {
			#if canImport(os)
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("URL Op id %d: Cannot log data %@ to debug logs: %@", log: $0, type: .info, urlOperationIdentifier, sentData, String(describing: error)) }}
				else                                                          {NSLog("*** URL Op id %d: Cannot log data %@ to debug logs: %@", urlOperationIdentifier, sentData, String(describing: error))}
			#else
				NSLogString("*** URL Op id \(urlOperationIdentifier): Cannot log data \(sentData) to debug logs: \(String(describing: error))")
			#endif
		}
	}
	
}


extension NSNotification.Name {
	
	fileprivate static let URLRequestOperationDidSucceedOperation = NSNotification.Name(rawValue: "fr.ftw-and-co.happn.notif.url_request_operation.did_succeed_request")
	
}
