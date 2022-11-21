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
#if canImport(os)
import os.log
#endif
import SystemConfiguration
#if os(tvOS) || os(iOS)
import UIKit
#endif

import Logging
import SemiSingleton



/* If we can drop @objc in ReachabilitySubscriber, we could drop NSObject’s inheritance.
 * See the ReachabilitySubscriber protocol for more information.
 *
 * Dev note: We have an unchecked conformance to Sendable because of wasReachable which is mutable.
 * We only use/modify this variable in a Lock-protected code, and it’s private, so we should be good. */
public final class ReachabilityObserver : NSObject, SemiSingletonWithFallibleInit, @unchecked Sendable {
	
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
	
	public enum InitInfo : Sendable, Hashable {
		
		case sockaddr(SockAddrWrapper)
		case host(String)
		
	}
	
	public enum Err : Int, Error, Sendable {
		
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
					throw Err.cannotCreateReachability
				}
				reachabilityRef = ref
				
			case .sockaddr(let addr):
				reachabilityRef = try addr.withUnsafeSockaddrPointer{ ptr in
					guard let ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, ptr) else {
						throw Err.cannotCreateReachability
					}
					return ref
				}
		}
		
		super.init()
		
		/* From tests I’ve done, it seems assessing unreachability because network is down seems to be synchronous,
		 *  so setting was reachable as soon as the reachability observer is instantiated makes sense. */
		wasReachable = currentlyReachable
		
		let container = WeakReachabilityObserverContainer(observer: self)
		var context = SCNetworkReachabilityContext(version: 0, info: unsafeBitCast(container, to: UnsafeMutableRawPointer.self), retain: reachabilityRetainForReachabilityObserver, release: reachabilityReleaseForReachabilityObserver, copyDescription: nil)
		guard SCNetworkReachabilitySetCallback(reachabilityRef, reachabilityCallbackForReachabilityObserver, &context) else {
			throw Err.cannotSetReachabilityCallback
		}
		
		isReachabilityScheduled = SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilityQueue)
#if os(tvOS) || os(iOS)
		appDidEnterBackgroundObserver = NotificationCenter.default.addObserver(forName: NotifNameGetter.didEnterBackgroundNotifName, object: nil, queue: nil){ [weak self] notif in
			guard let strongSelf = self, strongSelf.isReachabilityScheduled else {
				return
			}
			strongSelf.isReachabilityScheduled = !SCNetworkReachabilitySetDispatchQueue(strongSelf.reachabilityRef, nil)
		}
		appWillEnterForegroundObserver = NotificationCenter.default.addObserver(forName: NotifNameGetter.willEnterForegroundNotifName, object: nil, queue: nil){ [weak self] notif in
			guard let strongSelf = self, !strongSelf.isReachabilityScheduled else {
				return
			}
			if let f = strongSelf.currentReachabilityFlags() {strongSelf.reachabilityChanged(newFlags: f)}
			strongSelf.isReachabilityScheduled = SCNetworkReachabilitySetDispatchQueue(strongSelf.reachabilityRef, strongSelf.reachabilityQueue)
		}
#endif
	}
	
	deinit {
#if canImport(os)
		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			Conf.oslog.flatMap{ os_log("Deiniting a reachability observer with reachability ref %@", log: $0, type: .debug, String(describing: reachabilityRef)) }}
#endif
		Conf.logger?.debug("Deiniting a reachability observer with reachability ref \(String(describing: reachabilityRef))")
#if os(tvOS) || os(iOS)
		if let observer = appDidEnterBackgroundObserver  {NotificationCenter.default.removeObserver(observer, name: NotifNameGetter.didEnterBackgroundNotifName,  object: nil)}
		if let observer = appWillEnterForegroundObserver {NotificationCenter.default.removeObserver(observer, name: NotifNameGetter.willEnterForegroundNotifName, object: nil)}
#endif
		if isReachabilityScheduled && !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil) {
#if canImport(os)
			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
				Conf.oslog.flatMap{ os_log("Cannot remove dispatch queue from a reachability. We might crash later if reachability changes.", log: $0, type: .error) }}
#endif
			Conf.logger?.error("Cannot remove dispatch queue from a reachability. We might crash later if reachability changes.")
		}
		if !SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil) {
#if canImport(os)
			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
				Conf.oslog.flatMap{ os_log("Cannot unset callback from a reachability. We might crash later if reachability changes.", log: $0, type: .error) }}
#endif
			Conf.logger?.error("Cannot unset callback from a reachability. We might crash later if reachability changes.")
		}
		/* No need to release the reachability ref: it is implicitly bridged. */
	}
	
	public var currentlyReachable: Bool? {
		return currentReachabilityFlags().flatMap{ ReachabilityObserver.isReachableWithFlags($0) }
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
	
	fileprivate final class WeakReachabilityObserverContainer {
		weak var reachabilityObserver: ReachabilityObserver?
		init(observer: ReachabilityObserver) {
			reachabilityObserver = observer
#if canImport(os)
			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
				Conf.oslog.flatMap{ os_log("Inited Weak Reachability Observer Container %{public}@", log: $0, type: .debug, String(describing: Unmanaged.passUnretained(self).toOpaque())) }}
#endif
			Conf.logger?.debug("Inited Weak Reachability Observer Container \(String(describing: Unmanaged.passUnretained(self).toOpaque()))")
		}
		deinit {
#if canImport(os)
			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
				Conf.oslog.flatMap{ os_log("Deiniting Weak Reachability Observer Container %{public}@", log: $0, type: .debug, String(describing: Unmanaged.passUnretained(self).toOpaque())) }}
#endif
			Conf.logger?.debug("Deiniting Weak Reachability Observer Container \(String(describing: Unmanaged.passUnretained(self).toOpaque()))")
		}
	}
	
	private var wasReachable: Bool?
	
	private let subscribersLock = NSLock()
	private let subscribers = NSHashTable<ReachabilitySubscriber>.weakObjects()
	
	private let reachabilityRef: SCNetworkReachability
	private let reachabilityQueue = DispatchQueue.global(qos: .background)
	
	private var isReachabilityScheduled = false
	private var appDidEnterBackgroundObserver: NSObjectProtocol?
	private var appWillEnterForegroundObserver: NSObjectProtocol?
	
	fileprivate func reachabilityChanged(newFlags: SCNetworkReachabilityFlags) {
#if canImport(os)
		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			Conf.oslog.flatMap{ os_log("Reachability changed object callback with new flags %{public}@, in %@", log: $0, type: .debug, ReachabilityObserver.convertReachabilityFlagsToStr(newFlags), String(describing: self)) }}
#endif
		Conf.logger?.debug("Reachability changed object callback with new flags \(ReachabilityObserver.convertReachabilityFlagsToStr(newFlags)), in \(String(describing: self))")
		
		subscribersLock.lock()
		/* Reachability changed can be called from any thread.
		 * We must be locked when reading/writing wasReachable. */
		let isReachable = ReachabilityObserver.isReachableWithFlags(newFlags)
		let isReachableChanged = (isReachable != wasReachable)
		wasReachable = isReachable
		
		/* We do not iterate directly on the subscribers hash table.
		 * Indeed copying the subscribers to a static array is an operation of known complexity.
		 * If we iterated directly in the lock, we would allow code with unknown complexity to run while we're locked,
		 *  and potentially even trigger a dead-lock. */
		let subscribersArray = subscribers.allObjects
		subscribersLock.unlock()
		for subscriber in subscribersArray {
			subscriber.reachabilityChanged?(observer: self, newFlags: newFlags)
			if isReachableChanged {
				if isReachable {subscriber.reachabilityDidBecomeReachable?(observer: self)}
				else           {subscriber.reachabilityDidBecomeUnreachable?(observer: self)}
			}
		}
	}
	
}


private func reachabilityCallbackForReachabilityObserver(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, context: UnsafeMutableRawPointer?) -> Void {
#if canImport(os)
	if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
		Conf.oslog.flatMap{ os_log("Reachability changed function callback with new flags %{public}@", log: $0, type: .debug, ReachabilityObserver.convertReachabilityFlagsToStr(flags)) }}
#endif
	Conf.logger?.debug("Reachability changed function callback with new flags \(ReachabilityObserver.convertReachabilityFlagsToStr(flags))")
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
