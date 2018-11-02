/*
 * ReachabilityObserver.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 1/2/16.
 * Copyright © 2016 happn. All rights reserved.
 */

#if canImport(SystemConfiguration)

import Foundation
#if canImport(os)
	import os.log
#endif
import SystemConfiguration
#if os(iOS)
	import UIKit
#endif

#if !canImport(os) && canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif
import SemiSingleton



public final class ReachabilityObserver : SemiSingletonWithFallibleInit {
	
	public static func convertReachabilityFlagsToStr(_ flags: SCNetworkReachabilityFlags) -> String {
		#if os(iOS)
			let isWWANStr = (flags.contains(.isWWAN) ? "W" : "-")
		#else
			let isWWANStr = "X"
		#endif
		
		return (
			isWWANStr +
			(flags.contains(.reachable)            ? "R" : "-") +
			" " +
			(flags.contains(.connectionRequired)   ? "C" : "-") +
			(flags.contains(.transientConnection)  ? "T" : "-") +
			(flags.contains(.interventionRequired) ? "I" : "-") +
			(flags.contains(.connectionOnTraffic)  ? "t" : "-") +
			(flags.contains(.connectionOnDemand)   ? "d" : "-") +
			(flags.contains(.isLocalAddress)       ? "l" : "-") +
			(flags.contains(.isDirect)             ? "d" : "-")
		)
	}
	
	public static func isReachableWithFlags(_ flags: SCNetworkReachabilityFlags) -> Bool {
		return flags.contains(.reachable)
	}
	
	public typealias SemiSingletonKey = InitInfo
	public typealias SemiSingletonAdditionalInitInfo = Void
	
	public enum InitInfo : Hashable {
		
		case sockaddr(SockAddrWrapper)
		case host(String)
		
		public var hashValue: Int {
			switch self {
			case .host(let host):     return host.hashValue
			case .sockaddr(let addr): return Int.max/2 &+ addr.hashValue
			}
		}
		
		public static func ==(lhs: InitInfo, rhs: InitInfo) -> Bool {
			switch (lhs, rhs) {
			case (.sockaddr(let addr1), .sockaddr(let addr2)): return addr1 == addr2
			case (.host(let host1), .host(let host2)):         return host1 == host2
			default:                                           return false
			}
		}
		
	}
	
	public enum Error : Int, Swift.Error {
		
		case noError = 0
		
		case cannotCreateReachability
		case cannotSetReachabilityCallback
		
	}
	
	public static func reachabilityObserver(forIPv4AddressStr ipV4AddressStr: String, semiSingletonStore: SemiSingletonStore? = .shared) throws -> ReachabilityObserver {
		return try reachabilityObserver(forSockAddressWrapper: SockAddrWrapper(ipV4AddressStr: ipV4AddressStr), semiSingletonStore: semiSingletonStore)
	}
	
	public static func reachabilityObserver(forIPv6AddressStr ipV6AddressStr: String, semiSingletonStore: SemiSingletonStore? = .shared) throws -> ReachabilityObserver {
		return try reachabilityObserver(forSockAddressWrapper: SockAddrWrapper(ipV6AddressStr: ipV6AddressStr), semiSingletonStore: semiSingletonStore)
	}
	
	public static func reachabilityObserver(forSockAddressWrapper sockAddressWrapper: SockAddrWrapper, semiSingletonStore: SemiSingletonStore? = .shared) throws -> ReachabilityObserver {
		let initInfo = InitInfo.sockaddr(sockAddressWrapper)
		return try semiSingletonStore?.semiSingleton(forKey: initInfo) ?? ReachabilityObserver(info: initInfo)
	}
	
	public static func reachabilityObserver(forHost host: String, semiSingletonStore: SemiSingletonStore? = .shared) throws -> ReachabilityObserver {
		let initInfo = InitInfo.host(host)
		return try semiSingletonStore?.semiSingleton(forKey: initInfo) ?? ReachabilityObserver(info: initInfo)
	}
	
	public convenience init(key: InitInfo, additionalInfo: Void, store: SemiSingletonStore) throws {
		try self.init(info: key)
	}
	
	public init(info: InitInfo) throws {
		subscribersLock.name = "Lock for Reachability Observer of \(info)"
		
		switch info {
		case .host(let host):
			guard let ref = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, host) else {
				throw Error.cannotCreateReachability
			}
			reachabilityRef = ref
			
		case .sockaddr(let addr):
			reachabilityRef = try addr.withUnsafeSockaddrPointer{ ptr in
				guard let ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, ptr) else {
					throw Error.cannotCreateReachability
				}
				return ref
			}
		}
		
		let container = WeakReachabilityObserverContainer(observer: self)
		var context = SCNetworkReachabilityContext(version: 0, info: unsafeBitCast(container, to: UnsafeMutableRawPointer.self), retain: reachabilityRetainForReachabilityObserver, release: reachabilityReleaseForReachabilityObserver, copyDescription: nil)
		guard SCNetworkReachabilitySetCallback(reachabilityRef, reachabilityCallbackForReachabilityObserver, &context) else {
			throw Error.cannotSetReachabilityCallback
		}
		
		isReachabilityScheduled = SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilityQueue)
		#if os(iOS)
			appDidEnterBackgroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil){ [weak self] notif in
				guard let strongSelf = self, strongSelf.isReachabilityScheduled else {
					return
				}
				strongSelf.isReachabilityScheduled = !SCNetworkReachabilitySetDispatchQueue(strongSelf.reachabilityRef, nil)
			}
			appWillEnterForegroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil){ [weak self] notif in
				guard let strongSelf = self, !strongSelf.isReachabilityScheduled else {
					return
				}
				if let f = strongSelf.currentReachabilityFlags() {strongSelf.reachabilityChanged(newFlags: f)}
				strongSelf.isReachabilityScheduled = SCNetworkReachabilitySetDispatchQueue(strongSelf.reachabilityRef, strongSelf.reachabilityQueue)
			}
		#endif
	}
	
	deinit {
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Deiniting a reachability observer with reachability ref %@", log: $0, type: .debug, String(describing: reachabilityRef)) }}
		else                                             {NSLog("Deiniting a reachability observer with reachability ref %@", String(describing: reachabilityRef))}
		#if os(iOS)
			if let observer = appDidEnterBackgroundObserver  {NotificationCenter.default.removeObserver(observer, name: UIApplication.didEnterBackgroundNotification,  object: nil)}
			if let observer = appWillEnterForegroundObserver {NotificationCenter.default.removeObserver(observer, name: UIApplication.willEnterForegroundNotification, object: nil)}
		#endif
		if isReachabilityScheduled && !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil) {
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Cannot remove dispatch queue from a reachability. We might crash later if reachability changes.", log: $0, type: .error) }}
			else                                             {NSLog("Cannot remove dispatch queue from a reachability. We might crash later if reachability changes.")}
		}
		if !SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil) {
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Cannot unset callback from a reachability. We might crash later if reachability changes.", log: $0, type: .error) }}
			else                                             {NSLog("Cannot unset callback from a reachability. We might crash later if reachability changes.")}
		}
		/* No need to release the reachability ref: it is implicitly bridged. */
	}
	
	public var currentlyReachable: Bool {
		guard let currentReachabilityFlags = currentReachabilityFlags() else {
			/* If we cannot get the reachability flags, we assume we’re reachable. */
			return true
		}
		return ReachabilityObserver.isReachableWithFlags(currentReachabilityFlags)
	}
	
	public func currentReachabilityFlags() -> SCNetworkReachabilityFlags? {
		var ret = SCNetworkReachabilityFlags(rawValue: 0)
		if !SCNetworkReachabilityGetFlags(reachabilityRef, &ret) {return nil}
		return ret
	}
	
	public func add(subscriber s: ReachabilitySubscriber) {
		subscribersLock.lock()
		subscribers.add(s)
		subscribersLock.unlock()
	}
	
	public func remove(subscriber s: ReachabilitySubscriber) {
		subscribersLock.lock()
		subscribers.remove(s)
		subscribersLock.unlock()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	fileprivate class WeakReachabilityObserverContainer {
		weak var reachabilityObserver: ReachabilityObserver?
		init(observer: ReachabilityObserver) {
			reachabilityObserver = observer
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Inited Weak Reachability Observer Container %{public}@", log: $0, type: .debug, String(describing: Unmanaged.passUnretained(self).toOpaque())) }}
			else                                             {NSLog("Inited Weak Reachability Observer Container %@", String(describing: Unmanaged.passUnretained(self).toOpaque()))}
		}
		deinit {
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Deiniting Weak Reachability Observer Container %{public}@", log: $0, type: .debug, String(describing: Unmanaged.passUnretained(self).toOpaque())) }}
			else                                             {NSLog("Deiniting Weak Reachability Observer Container %@", String(describing: Unmanaged.passUnretained(self).toOpaque()))}
		}
	}
	
	private var wasReachable: Bool? = nil
	
	private let subscribersLock = NSLock()
	private let subscribers = NSHashTable<ReachabilitySubscriber>.weakObjects()
	
	private let reachabilityRef: SCNetworkReachability
	private let reachabilityQueue = DispatchQueue.global(qos: .background)
	
	private var isReachabilityScheduled = false
	private var appDidEnterBackgroundObserver: NSObjectProtocol?
	private var appWillEnterForegroundObserver: NSObjectProtocol?
	
	fileprivate func reachabilityChanged(newFlags: SCNetworkReachabilityFlags) {
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Reachability changed object callback with new flags %{public}@, in %@", log: $0, type: .debug, ReachabilityObserver.convertReachabilityFlagsToStr(newFlags), String(describing: self)) }}
		else                                             {NSLog("Reachability changed object callback with new flags %@, in %@", ReachabilityObserver.convertReachabilityFlagsToStr(newFlags), String(describing: self))}
		
		subscribersLock.lock()
		/* Reachability changed can be called from any thread. We must be locked
		 * when reading/writing wasReachable. */
		let isReachable = ReachabilityObserver.isReachableWithFlags(newFlags)
		let isReachableChanged = (isReachable != wasReachable)
		wasReachable = isReachable
		
		/* We do not iterate directly on the subscribers hash table. Indeed
		 * copying the subscribers to a static array is an operation of known
		 * complexity. If we iterated directly in the lock, we would allow code
		 * with unknown complexity to run while we're locked and potentially even
		 * trigger a dead-lock. */
		let subscribersArray = subscribers.allObjects
		subscribersLock.unlock()
		for subscriber in subscribersArray {
			subscriber.reachabilityChanged(observer: self, newFlags: newFlags)
			if isReachableChanged {
				if isReachable {subscriber.reachabilityDidBecomeReachable(observer: self)}
				else           {subscriber.reachabilityDidBecomeUnreachable(observer: self)}
			}
		}
	}
	
}


private func reachabilityCallbackForReachabilityObserver(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, context: UnsafeMutableRawPointer?) -> Void {
	if #available(OSX 10.12, tvOS 10.0, iOS 10.0, *) {di.log.flatMap{ os_log("Reachability changed function callback with new flags %{public}@", log: $0, type: .debug, ReachabilityObserver.convertReachabilityFlagsToStr(flags)) }}
	else                                             {NSLog("Reachability changed function callback with new flags %@", ReachabilityObserver.convertReachabilityFlagsToStr(flags))}
	unsafeBitCast(context, to: ReachabilityObserver.WeakReachabilityObserverContainer.self).reachabilityObserver?.reachabilityChanged(newFlags: flags)
}

private func reachabilityRetainForReachabilityObserver(input: UnsafeRawPointer) -> UnsafeRawPointer {
	let u = Unmanaged.passRetained(unsafeBitCast(input, to: ReachabilityObserver.WeakReachabilityObserverContainer.self))
	return unsafeBitCast(u.takeUnretainedValue(), to: UnsafeRawPointer.self)
}

private func reachabilityReleaseForReachabilityObserver(input: UnsafeRawPointer) -> Void {
	let u = Unmanaged.passUnretained(unsafeBitCast(input, to: ReachabilityObserver.WeakReachabilityObserverContainer.self))
	u.release()
}

#endif
