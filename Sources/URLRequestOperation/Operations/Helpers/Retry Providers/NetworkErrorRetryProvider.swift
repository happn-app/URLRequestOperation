import Foundation

import RetryingOperation



extension NSNotification.Name {
	
	public static let URLRequestOperationNetworkErrorRetryProviderShouldResetRetryCount = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.NetworkErrorRetryProviderShouldResetRetryCount")
	
}


/**
 A retry provider that can provide a retry helper for exponential backoff retry,
 with potential early retry on reachability and “other success on same domain”. */
public final class NetworkErrorRetryProvider : RetryProvider {
	
	public static let idempotentHTTPMethods = Set(arrayLiteral: "GET", "HEAD", "PUT", "DELETE", "OPTIONS", "TRACE")
	
	public static func exponentialBackoffTimeForIndex(_ idx: Int) -> TimeInterval {
		let retryDelays: [TimeInterval] = Conf.networkRetryProviderBackoffTable
		
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
	
	public private(set) var currentNumberOfRetriesPerOperation = [URLRequestOperationID: Int]()
	
	public init(
		maximumNumberOfRetries: Int? = URLRequestOperationConfig.networkRetryProviderDefaultNumberOfRetries,
		alsoRetryNonIdempotentRequests: Bool = false,
		allowOtherSuccessObserver: Bool = true,
		allowReachabilityObserver: Bool = true,
		notificationCenter: NotificationCenter = .default
	) {
		self.maximumNumberOfRetries = maximumNumberOfRetries
		self.alsoRetryNonIdempotentRequests = alsoRetryNonIdempotentRequests
		self.allowOtherSuccessObserver = allowOtherSuccessObserver
		self.allowReachabilityObserver = allowReachabilityObserver
		
		notifObservers.append(contentsOf: [
			notificationCenter.addObserver(forName: .URLRequestOperationNetworkErrorRetryProviderShouldResetRetryCount, object: nil, queue: nil, using: { [weak self] n in
				guard let urlOpID = n.object as? URLRequestOperationID else {
					Conf.logger?.warning("Got notif telling retry provider should reset retry count, but object of notif is not an URLRequestOperationID: \(String(describing: n.object))")
					return
				}
				Self.syncQ.sync{ self?.currentNumberOfRetriesPerOperation[urlOpID] = 0 }
			}),
			notificationCenter.addObserver(forName: .URLRequestOperationDidSucceedOperation, object: nil, queue: nil, using: { [weak self] n in
				guard let urlOpID = n.object as? URLRequestOperationID else {
					Conf.logger?.warning("Got notif telling URL request operation did succeed, but object of notif is not an URLRequestOperationID: \(String(describing: n.object))")
					return
				}
				Self.syncQ.sync{ _ = self?.currentNumberOfRetriesPerOperation.removeValue(forKey: urlOpID) }
			})
		])
	}
	
	public func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?? {
		guard Self.isRequestIdempotent(request) || alsoRetryNonIdempotentRequests else {
			/* We don’t want to retry non-idempotent requests, but we’ll not block other retry provider to retry them if they want. */
			return nil
		}
		let currentNumberOfRetries = Self.syncQ.sync{ currentNumberOfRetriesPerOperation[operation.urlOperationIdentifier, default: 0] }
		guard maximumNumberOfRetries.flatMap({ currentNumberOfRetries < $0 }) ?? true else {
			/* We don’t want to retry after max number of retries, but we’ll not block other retry provider to retry them if they want. */
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
		Self.syncQ.sync{ currentNumberOfRetriesPerOperation[operation.urlOperationIdentifier, default: 0] += 1 }
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
	
	private static let syncQ = DispatchQueue(label: "com.happn.URLRequestOperation.NetworkErrorRetryProviderSyncQ")
	
	private var notifObservers = [NSObjectProtocol]()
	
}
