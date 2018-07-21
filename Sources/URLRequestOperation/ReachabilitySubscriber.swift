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
	/* The protocol only have optional methods. Optional methods are not
	 * available in pure Swift (this is being discussed in swift-evolution but is
	 * not done yet); but we can use default implementations instead. The methods
	 * of this protocol are thus all in an exension below.
	 *
	 * But, will you say, you have an @objc’d protocol!
	 * Yes, it’s true. However, the methods in this protocol use a type that
	 * cannot be represented in ObjC, so we can’t @objc _those_.
	 *
	 * Why the @objc on the protocol you ask again? Good question!
	 * Because we use conformers of this protocol in an NSHashTable to have a
	 * weak array of subscribers. NSHashTable is not fully swifty those days, and
	 * requires it’s contained type to be @objc. We could have created a wrapper
	 * and dropped the @objc on the protocol, but it is not worth the trouble and
	 * (potential) overhead. */
}

public extension ReachabilitySubscriber {
	
	/* Both methods below are sent only when reachability actually changes. If a
	 * reachability notification notifies of a reachable state to a reachable
	 * state, the function reachabilityDidBecomeReachableFromObserver(_:) will
	 * not be called (and vice-versa). */
	func reachabilityDidBecomeReachable(observer: ReachabilityObserver) {}
	func reachabilityDidBecomeUnreachable(observer: ReachabilityObserver) {}
	
	func reachabilityChanged(observer: ReachabilityObserver, newFlags: SCNetworkReachabilityFlags) {}
	
}

#endif
