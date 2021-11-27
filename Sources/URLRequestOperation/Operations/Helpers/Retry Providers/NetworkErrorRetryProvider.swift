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
	
	public private(set) var currentNumberOfRetries: Int = 0
	
	public init(
		maximumNumberOfRetries: Int? = nil,
		alsoRetryNonIdempotentRequests: Bool = false,
		allowOtherSuccessObserver: Bool = true,
		allowReachabilityObserver: Bool = true
	) {
		self.maximumNumberOfRetries = maximumNumberOfRetries
		self.alsoRetryNonIdempotentRequests = alsoRetryNonIdempotentRequests
		self.allowOtherSuccessObserver = allowOtherSuccessObserver
		self.allowReachabilityObserver = allowReachabilityObserver
	}
	
	public func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?? {
		guard Self.isRequestIdempotent(request) || alsoRetryNonIdempotentRequests else {
			/* We don’t want to retry non-idempotent requests, but we’ll not block other retry provider to retry them if they want. */
			return nil
		}
		guard maximumNumberOfRetries.flatMap({ currentNumberOfRetries < $0 }) ?? true else {
			/* We don’t want to retry after max number of retries, but we’ll not block other retry provider to retry them if they want. */
			return nil
		}
		guard (error as NSError).domain != NSURLErrorDomain || (error as NSError).code != URLError.cancelled.rawValue else {
			/* We don’t want to retry cancelled tasks, but we’ll not block other retry provider to retry them if they want. */
			return nil
		}
		
		/* We now know the request CAN be retried (idempotent and maximum number of retries not exceeded, task not cancelled). */
		currentNumberOfRetries += 1
		let host = request.url?.host
#if canImport(SystemConfiguration)
		return ([
			RetryingOperation.TimerRetryHelper(retryDelay: Self.exponentialBackoffTimeForIndex(currentNumberOfRetries - 1), retryingOperation: operation),
			allowReachabilityObserver ? ReachabilityRetryHelper(host: host, operation: operation) : nil,
			allowOtherSuccessObserver ? OtherSuccessRetryHelper(host: host, operation: operation) : nil
		] as [RetryHelper?]).compactMap{ $0 }
#else
		return ([
			RetryingOperation.TimerRetryHelper(retryDelay: Self.exponentialBackoffTimeForIndex(currentNumberOfRetries - 1), retryingOperation: operation),
			allowOtherSuccessObserver ? OtherSuccessRetryHelper(host: host, operation: operation) : nil
		] as [RetryHelper?]).compactMap{ $0 }
#endif
	}
	
}
