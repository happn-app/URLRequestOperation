/*
Copyright 2019-2021 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

#if canImport(SystemConfiguration)

import Foundation
import SystemConfiguration



@objc
public protocol ReachabilitySubscriber : AnyObject {
	/* We do not have optional methods in a protocol in (pure) Swift.
	 * So we cheat and use the ObjC feature.
	 * An earlier solution was to implement the methods as an extension of the protocol (with empty implementations),
	 *  but that failed, because Swift called the empty implementations instead of the overrides when an override exists.
	 * Also we store subscribers in an NSHashTable which requires its objects to be @objc somehow. */
	
	/* Both methods below are sent only when reachability actually changes.
	 * If a reachability notification notifies of a reachable state to a reachable state,
	 *  the function reachabilityDidBecomeReachableFromObserver(_:) will not be called (and vice-versa). */
	@objc optional func reachabilityDidBecomeReachable(observer: ReachabilityObserver)
	@objc optional func reachabilityDidBecomeUnreachable(observer: ReachabilityObserver)
	
	@objc optional func reachabilityChanged(observer: ReachabilityObserver, newFlags: SCNetworkReachabilityFlags)
	
}

#endif
