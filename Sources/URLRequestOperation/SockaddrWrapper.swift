/*
 * IPUtils.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 1/20/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

#if !canImport(os) && canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif



public enum SockAddrConversionError : Int, Error {
	
	case noError = 0
	
	case cannotConvertDataToString
	case unknownSockaddrFamily
	case invalidInput
	
	case systemError
	
}


public class SockAddrWrapper : Hashable, CustomStringConvertible {
	
	let len: Int /* Original type is __uint8_t */
	let family: sa_family_t
	let rawPointer: UnsafeMutableRawPointer
	
	public convenience init(ipV4AddressStr: String) throws {
		var sa4 = sockaddr_in()
		sa4.sin_family = sa_family_t(AF_INET)
		sa4.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
		let successValue = inet_pton(AF_INET, ipV4AddressStr, &sa4.sin_addr)
		try SockAddrWrapper.processInetPToN(returnValue: successValue)
		
		self.init(rawsockaddr: &sa4)
	}
	
	public convenience init(ipV6AddressStr: String) throws {
		var sa6 = sockaddr_in6()
		sa6.sin6_family = sa_family_t(AF_INET6)
		sa6.sin6_len = __uint8_t(MemoryLayout<sockaddr_in6>.size)
		let successValue = inet_pton(AF_INET6, ipV6AddressStr, &sa6.sin6_addr)
		try SockAddrWrapper.processInetPToN(returnValue: successValue)
		
		self.init(rawsockaddr: &sa6)
	}
	
	/** The given sockaddr is copied */
	public convenience init(sockaddr_in sa4Ptr: UnsafePointer<sockaddr_in>) {
		self.init(rawsockaddr: UnsafeRawPointer(sa4Ptr))
	}
	
	/** The given sockaddr is copied */
	public convenience init(sockaddr_in6 sa6Ptr: UnsafePointer<sockaddr_in6>) {
		self.init(rawsockaddr: UnsafeRawPointer(sa6Ptr))
	}
	
	/** The given sockaddr is copied */
	public convenience init(sockaddr: UnsafePointer<sockaddr>) {
		self.init(rawsockaddr: UnsafeRawPointer(sockaddr))
	}
	
	init(rawsockaddr: UnsafeRawPointer) {
		let sockaddrPtr = rawsockaddr.assumingMemoryBound(to: sockaddr.self)
		len = Int(sockaddrPtr.pointee.sa_len)
		family = sockaddrPtr.pointee.sa_family
		rawPointer = UnsafeMutableRawPointer.allocate(byteCount: len, alignment: MemoryLayout<sockaddr>.alignment /* Not sure about that though... */)
		rawPointer.copyMemory(from: rawsockaddr, byteCount: len)
	}
	
	deinit {
		rawPointer.deallocate()
	}
	
	public func sockaddrStringRepresentation() throws -> String {
		let len = socklen_t(max(INET_ADDRSTRLEN, INET6_ADDRSTRLEN))
		var data = Data(capacity: Int(len))
		
		try data.withUnsafeMutableBytes{ (rwBuffer: UnsafeMutablePointer<Int8>) -> Void in
			switch rawPointer.assumingMemoryBound(to: sockaddr.self).pointee.sa_family {
			case sa_family_t(AF_INET):
				let s = inet_ntop(AF_INET, &rawPointer.assumingMemoryBound(to: sockaddr_in.self).pointee.sin_addr, rwBuffer, len)
				guard OpaquePointer(s) == OpaquePointer(rwBuffer) else {
					throw SockAddrConversionError.systemError
				}
				
			case sa_family_t(AF_INET6):
				let s = inet_ntop(AF_INET6, &rawPointer.assumingMemoryBound(to: sockaddr_in6.self).pointee.sin6_addr, rwBuffer, len)
				guard OpaquePointer(s) == OpaquePointer(rwBuffer) else {
					throw SockAddrConversionError.systemError
				}
				
			default:
				throw SockAddrConversionError.unknownSockaddrFamily
			}
		}
		
		return try data.withUnsafeBytes{ (ccharBuffer: UnsafePointer<CChar>) -> String in
			guard let ret = String(cString: ccharBuffer, encoding: .ascii) else {
				throw SockAddrConversionError.cannotConvertDataToString
			}
			return ret
		}
	}
	
	public func withUnsafeSockaddrPointer<T>(_ handler: (_ sockaddrPtr: UnsafePointer<sockaddr>) throws -> T) rethrows -> T {
		return try handler(rawPointer.assumingMemoryBound(to: sockaddr.self))
	}
	
	public var description: String {
		return "sockaddr wrapper for <\((try? sockaddrStringRepresentation()) ?? "Unknown sockaddr String Representation")>"
	}
	
	public var hashValue: Int {
		/* Is this hash computation really wise? It is probably the safest way to
		 * do it, but I think we could go faster than converting the address to a
		 * String... */
		return ((try? sockaddrStringRepresentation())?.hashValue ?? 0)
	}
	
	public static func ==(lhs: SockAddrWrapper, rhs: SockAddrWrapper) -> Bool {
		guard lhs.len == rhs.len else {return false}
		guard lhs.family == rhs.family else {return false}
		
		switch lhs.family {
		case sa_family_t(AF_INET):
			/* IPv4 */
			let lhs4Ptr = lhs.rawPointer.assumingMemoryBound(to: sockaddr_in.self)
			let rhs4Ptr = rhs.rawPointer.assumingMemoryBound(to: sockaddr_in.self)
			guard lhs4Ptr.pointee.sin_port == rhs4Ptr.pointee.sin_port else {return false}
			guard lhs4Ptr.pointee.sin_addr.s_addr == rhs4Ptr.pointee.sin_addr.s_addr else {return false}
			return true
			
		case sa_family_t(AF_INET6):
			/* IPv6 */
			let lhs6Ptr = lhs.rawPointer.assumingMemoryBound(to: sockaddr_in6.self)
			let rhs6Ptr = rhs.rawPointer.assumingMemoryBound(to: sockaddr_in6.self)
			guard lhs6Ptr.pointee.sin6_port == rhs6Ptr.pointee.sin6_port else {return false}
			guard lhs6Ptr.pointee.sin6_flowinfo == rhs6Ptr.pointee.sin6_flowinfo else {return false}
			guard lhs6Ptr.pointee.sin6_scope_id == rhs6Ptr.pointee.sin6_scope_id else {return false}
			return memcmp(&lhs6Ptr.pointee.sin6_addr, &rhs6Ptr.pointee.sin6_addr, MemoryLayout.size(ofValue: lhs6Ptr.pointee.sin6_addr)) == 0
			
		default:
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("Got unknown family when comparing two SockAddrWrapper", log: $0, type: .error) }}
			else                                                          {NSLog("Got unknown family when comparing two SockAddrWrapper")}
			return false
		}
	}
	
	private static func processInetPToN(returnValue v: Int32) throws {
		switch v {
		case 1: (/* Nothing to do, the input was valid. */)
		case 0: throw SockAddrConversionError.invalidInput
		case -1: fallthrough
		default: /* No other case than 1, 0 or -1 should happen. We consider any other value to be -1. */
			if v != -1 {
				if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("Got unknown return value from inet_pton: %d. Treating as -1.", log: $0, type: .info, v) }}
				else                                                          {NSLog("Got unknown return value from inet_pton: %d. Treating as -1.", v)}
			}
			throw SockAddrConversionError.systemError
		}
	}
	
}
