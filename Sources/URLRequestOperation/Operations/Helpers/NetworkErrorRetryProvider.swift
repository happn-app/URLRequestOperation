import Foundation

import RetryingOperation



/**
 A retry provider that can provide a retry helper for exponential backoff retry,
 with potential early retry on reachability and “other success on same domain”. */
public final class NetworkErrorRetryProvider : RetryProvider {
	
	public static let idempotentHTTPMethods = Set(arrayLiteral: "GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE")
	
	public static func exponentialBackoffTimeForIndex(_ idx: Int) -> TimeInterval {
		/* First retry is after one second max;
		 * next retry is after three seconds max;
		 * next retry is after one minute max;
		 * next retry is after one hour max;
		 * next retry (and all subsequent retries) are after six hours max. */
		let retryDelays: [TimeInterval] = [1, 3, 60, 60 * 60, 6 * 60 * 60]
		
		let idx = max(0, min(idx, retryDelays.count - 1))
		return TimeInterval.random(in: 0..<retryDelays[idx])
	}
	
	public static func isRequestIdempotent(_ urlRequest: URLRequest) -> Bool {
		guard let method = urlRequest.httpMethod else {
			return false
		}
		
		return idempotentHTTPMethods.contains(method)
	}
	
	public let maximumNumberOfRetries: Int?
	public let alsoRetryNonIdempotentRequests: Bool
	
	public let allowOtherSuccessObserver: Bool
	public let allowReachabilityObserver: Bool
	
	/**
	 This handler is called to determine if the given error is an error known not to be retryable.
	 
	 - Note: The cancelled errors from `NSURLErrorDomain` and ``URLRequestOperation`` are always considered unretryable. */
	public let isKnownUnretryableErrors: (Error) -> Bool
	
	public private(set) var currentNumberOfRetries: Int = 0
	
	public init(
		maximumNumberOfRetries: Int? = nil,
		alsoRetryNonIdempotentRequests: Bool = false,
		allowOtherSuccessObserver: Bool = true,
		allowReachabilityObserver: Bool = true,
		isKnownUnretryableErrors: @escaping (Error) -> Bool = { _ in false }
	) {
		self.maximumNumberOfRetries = maximumNumberOfRetries
		self.alsoRetryNonIdempotentRequests = alsoRetryNonIdempotentRequests
		self.allowOtherSuccessObserver = allowOtherSuccessObserver
		self.allowReachabilityObserver = allowReachabilityObserver
		self.isKnownUnretryableErrors = isKnownUnretryableErrors
	}
	
	public func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]? {
		guard Self.isRequestIdempotent(request) || alsoRetryNonIdempotentRequests else {
			return nil
		}
		guard maximumNumberOfRetries.flatMap({ currentNumberOfRetries < $0 }) ?? true else {
			return nil
		}
		
		/* We now know the request CAN be retried (idempotent and maximum number of retries not exceeded).
		 * Should we retry? */
		let isCancelledError = (
			error as? URLRequestOperationError == .operationCancelled ||
			((error as NSError).domain == NSURLErrorDomain && (error as NSError).code == URLError.cancelled.rawValue)
		)
		guard !isCancelledError && !isKnownUnretryableErrors(error) else {
			return nil
		}
		
		/* Let’s retry. */
		currentNumberOfRetries += 1
		let host = request.url?.host
		return ([
			RetryingOperation.TimerRetryHelper(retryDelay: Self.exponentialBackoffTimeForIndex(currentNumberOfRetries - 1), retryingOperation: operation),
			allowReachabilityObserver ? ReachabilityRetryHelper(host: host, operation: operation) : nil,
			allowOtherSuccessObserver ? OtherSuccessRetryHelper(host: host, operation: operation) : nil
		] as [RetryHelper?]).compactMap{ $0 }
	}
	
}
