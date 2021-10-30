import Foundation

import RetryingOperation



#if canImport(SystemConfiguration)

private class ReachabilityRetryHelper : NSObject, RetryHelper, ReachabilitySubscriber {
	
	init?(host: String?, operation op: RetryingOperation) {
		guard let host = host, let o = try? ReachabilityObserver.reachabilityObserver(forHost: host) else {return nil}
		operation = op
		observer = o
	}
	
	func setup() {
		/* In theory we’re supposed to create the reachability observer here instead of directly when initing the object
		 * (the observer cannot be told to wait until a given moment for starting observing the reachability).
		 * Anyway we know at 99.99999% the setup will be started promply after initing the helper… */
		observer.add(subscriber: self)
	}
	
	func teardown() {
		observer.remove(subscriber: self)
	}
	
	func reachabilityDidBecomeReachable(observer: ReachabilityObserver) {
//#if canImport(os)
//		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
//			URLRequestOperationConfig.oslog.flatMap{ os_log("URL Op id %d: The reachability observer tells me the host is reachable again. Let’s force retrying the operation sooner.", log: $0, type: .debug, operation.urlOperationIdentifier) }}
//#endif
//		URLRequestOperationConfig.logger?.debug("URL Op id \(operation.urlOperationIdentifier): The reachability observer tells me the host is reachable again. Let’s force retrying the operation sooner.")
		operation.retry(in: SimpleErrorRetryProvider.exponentialBackoffTimeForIndex(1))
	}
	
	private let observer: ReachabilityObserver
	private let operation: RetryingOperation
	
}

#endif
