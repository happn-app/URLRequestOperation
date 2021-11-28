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



#if canImport(SystemConfiguration)

public final class ReachabilityRetryHelper : NSObject, RetryHelper, ReachabilitySubscriber {
	
	public init?(host: String?, operation op: URLRequestOperation) {
		guard let host = host, let o = try? ReachabilityObserver.reachabilityObserver(forHost: host) else {return nil}
		operation = op
		observer = o
	}
	
	public func setup() {
		/* In theory we’re supposed to create the reachability observer here instead of directly when initing the object
		 * (the observer cannot be told to wait until a given moment for starting observing the reachability).
		 * Anyway we know at 99.99999% the setup will be started promply after initing the helper… */
		observer.add(subscriber: self)
	}
	
	public func teardown() {
		observer.remove(subscriber: self)
	}
	
	public func reachabilityDidBecomeReachable(observer: ReachabilityObserver) {
#if canImport(os)
		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			Conf.oslog.flatMap{ os_log("URLOpID %{public}@: The reachability observer tells me the host is reachable again. Let’s force retrying the operation sooner.", log: $0, type: .debug, String(describing: self.operation.urlOperationIdentifier)) }}
#endif
		Conf.logger?.debug("The reachability observer tells me the host is reachable again. Let’s force retrying the operation sooner.", metadata: [LMK.operationID: "\(self.operation.urlOperationIdentifier)"])
		operation.retry(in: NetworkErrorRetryProvider.exponentialBackoffTimeForIndex(1))
	}
	
	private let observer: ReachabilityObserver
	private let operation: URLRequestOperation
	
}

#endif
