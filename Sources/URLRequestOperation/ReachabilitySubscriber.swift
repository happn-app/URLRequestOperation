/*
 * ReachabilitySubscriber.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 1/20/18.
 * Copyright © 2018 happn. All rights reserved.
 */

#if canImport(SystemConfiguration)

import Foundation
import SystemConfiguration



@objc
public protocol ReachabilitySubscriber : class {
	/* We do not have optional methods in a protocol in (pure) Swift. So we cheat
	 * and use the ObjC feature.
	 * An earlier solution was to implement the methods as an extension of the
	 * protocol (with empty implementations), but that failed, because Swift
	 * called the empty implementations instead of the overrides when an override
	 * exists.
	 * See the history of this file for more information! */
	
	/* Both methods below are sent only when reachability actually changes. If a
	 * reachability notification notifies of a reachable state to a reachable
	 * state, the function reachabilityDidBecomeReachableFromObserver(_:) will
	 * not be called (and vice-versa). */
	@objc optional func reachabilityDidBecomeReachable(observer: ReachabilityObserver)
	@objc optional func reachabilityDidBecomeUnreachable(observer: ReachabilityObserver)
	
	@objc optional func reachabilityChanged(observer: ReachabilityObserver, newFlags: SCNetworkReachabilityFlags)
	
}

#endif
