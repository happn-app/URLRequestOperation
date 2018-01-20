/*
 * IPUtils.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 1/20/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
import os.log



public enum SockAddrConversionError : Int, Error {
	
	case noError = 0
	
	case cannotConvertDataToString
	case unknownSockaddrFamily
	case invalidInput
	
	case systemError
	
}


extension sockaddr : Hashable, CustomStringConvertible {
	
	public var description: String {
		return "sockaddr <\((try? toString()) ?? "Unknown String Representation")>"
	}
	
	public var hashValue: Int {
		/* Is this hash computation really wise? It is probably the safest way to
		 * do it, but I think we could go faster than converting the address to a
		 * String... */
		return ((try? toString())?.hashValue ?? 0)
	}
	
	public static func ==(lhs: sockaddr, rhs: sockaddr) -> Bool {
		let len = lhs.sa_len
		let family = lhs.sa_family
		
		guard len == rhs.sa_len else {return false}
		guard family == rhs.sa_family else {return false}
		
		switch family {
		case sa_family_t(AF_INET):
			/* IPv4 */
			let lhs4 = unsafeBitCast(lhs, to: sockaddr_in.self)
			let rhs4 = unsafeBitCast(rhs, to: sockaddr_in.self)
			guard lhs4.sin_port == rhs4.sin_port else {return false}
			guard lhs4.sin_addr.s_addr == rhs4.sin_addr.s_addr else {return false}
			return true
			
		case sa_family_t(AF_INET6):
			/* IPv6 */
			var lhs6 = unsafeBitCast(lhs, to: sockaddr_in6.self)
			var rhs6 = unsafeBitCast(rhs, to: sockaddr_in6.self)
			guard lhs6.sin6_port == rhs6.sin6_port else {return false}
			guard lhs6.sin6_flowinfo == rhs6.sin6_flowinfo else {return false}
			guard lhs6.sin6_scope_id == rhs6.sin6_scope_id else {return false}
			return memcmp(&lhs6.sin6_addr, &rhs6.sin6_addr, MemoryLayout.size(ofValue: lhs6.sin6_addr)) == 0
			
		default:
			if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {di.log.flatMap{ os_log("Got unknown family when comparing two sockaddr", log: $0, type: .error) }}
			else                                                          {NSLog("Got unknown family when comparing two sockaddr")}
			return false
		}
	}
	
	func toString() throws -> String {
		let len = socklen_t(max(INET_ADDRSTRLEN, INET6_ADDRSTRLEN))
		var data = Data(capacity: Int(len))
		
		try data.withUnsafeMutableBytes{ (rwBuffer: UnsafeMutablePointer<Int8>) -> Void in
			switch sa_family {
			case sa_family_t(AF_INET):
				/* We create a var because we have to (inet_ntop requires a pointer
				 * to it, which in Swift’s terms means it will modify it, but it
				 * actually won’t: type is “const void * restrict”). */
				var ipv4_sockaddr = unsafeBitCast(self, to: sockaddr_in.self)
				let s = inet_ntop(AF_INET, &ipv4_sockaddr.sin_addr, rwBuffer, len)
				guard OpaquePointer(s) == OpaquePointer(rwBuffer) else {
					throw SockAddrConversionError.systemError
				}
				
			case sa_family_t(AF_INET6):
				var ipv6_sockaddr = unsafeBitCast(self, to: sockaddr_in6.self)
				let s = inet_ntop(AF_INET6, &ipv6_sockaddr.sin6_addr, rwBuffer, len)
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
	
}


func processInetPToN(returnValue v: Int32) throws {
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
