import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import RetryingOperation



extension NSNotification.Name {
	
	public static let URLRequestOperationNetworkErrorRetryProviderShouldResetRetryCount = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.NetworkErrorRetryProviderShouldResetRetryCount")
	
}


/**
 A retry provider that can provide a retry helper for exponential backoff retry,
  with potential early retry on reachability and “other success on same domain.” */
public final class NetworkErrorRetryProvider : RetryProvider, @unchecked Sendable {
	
	public static let idempotentHTTPMethods = Set(arrayLiteral: "GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE", "QUERY")
	
	public static func exponentialBackoffTimeForIndex(_ idx: Int) -> TimeInterval {
		let retryDelays: [TimeInterval] = Conf.networkRetryProviderBackoffTable
		
		let idx = max(0, min(idx, retryDelays.count - 1))
		return TimeInterval.random(in: 0..<retryDelays[idx])
	}
	
	public static func isRequestIdempotent(_ urlRequest: URLRequest) -> Bool {
		guard let method = urlRequest.httpMethod?.uppercased() else {
			return false
		}
		
		return idempotentHTTPMethods.contains(method)
	}
	
	public let maximumNumberOfRetries: Int?
	public let alsoRetryNonIdempotentRequests: Bool
	
	public let allowOtherSuccessObserver: Bool
	public let allowReachabilityObserver: Bool
	
	public private(set) var numberOfRetriesPerOperation = RetryCountsHolder(resetTryCountNotifName: .URLRequestOperationNetworkErrorRetryProviderShouldResetRetryCount)
	
	public init(
		maximumNumberOfRetries: Int? = URLRequestOperationConfig.networkRetryProviderDefaultNumberOfRetries,
		alsoRetryNonIdempotentRequests: Bool = false,
		allowOtherSuccessObserver: Bool = true,
		allowReachabilityObserver: Bool = true
	) {
		self.maximumNumberOfRetries = maximumNumberOfRetries
		self.alsoRetryNonIdempotentRequests = alsoRetryNonIdempotentRequests
		self.allowOtherSuccessObserver = allowOtherSuccessObserver
		self.allowReachabilityObserver = allowReachabilityObserver
	}
	
	public func retryHelpers(for request: URLRequest, error: URLRequestOperationError, operation: URLRequestOperation) -> [RetryHelper]?? {
		guard let error = error.urlSessionError else {
			/* The error is not an URLSession error, we do not retry this, but do not block other retry providers from retrying if they want. */
			return nil
		}
		guard Self.isRequestIdempotent(request) || alsoRetryNonIdempotentRequests else {
			/* We don’t want to retry non-idempotent requests, but we’ll not block other retry provider from retrying them if they want. */
			return nil
		}
		let currentNumberOfRetries = numberOfRetriesPerOperation[operation.urlOperationIdentifier, default: 0]
		guard (maximumNumberOfRetries.flatMap{ currentNumberOfRetries < $0 } ?? true) else {
			/* We don’t want to retry after max number of retries, but we’ll not block other retry provider from retrying them if they want. */
			return nil
		}
		let nserror = error as NSError
		guard nserror.domain != NSURLErrorDomain || nserror.code != URLError.cancelled.rawValue else {
			/* We don’t want to retry cancelled tasks, but we’ll not block other retry provider to retry them if they want. */
			return nil
		}
		
		/* TODO: Properly handle 503 (where the Retry-After header should be sent to tell when to retry)
		 *       Note: We might want to do this in a separate retry provider. */
		
		/* We now know the request CAN be retried (idempotent and maximum number of retries not exceeded, task not cancelled). */
		numberOfRetriesPerOperation[operation.urlOperationIdentifier, default: 0] += 1
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
