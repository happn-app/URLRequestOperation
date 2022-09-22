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

import Foundation
#if canImport(os)
import os.log
#endif

import Logging



public enum SockAddrConversionError : Int, Error, Sendable {
	
	case noError = 0
	
	case cannotConvertDataToString
	case unknownSockaddrFamily
	case invalidInput
	
	case systemError
	
}


public final class SockAddrWrapper : Sendable, Hashable, CustomStringConvertible {
	
#if !os(Linux)
	let len: Int /* Original type is __uint8_t */
#endif
	let family: sa_family_t
	let rawPointer: UnsafeMutableRawPointer
	
	public convenience init(ipV4AddressStr: String) throws {
		var sa4 = sockaddr_in()
		sa4.sin_family = sa_family_t(AF_INET)
#if !os(Linux)
		sa4.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
#endif
		let successValue = inet_pton(AF_INET, ipV4AddressStr, &sa4.sin_addr)
		try SockAddrWrapper.processInetPToN(returnValue: successValue)
		
		self.init(rawsockaddr: &sa4)
	}
	
	public convenience init(ipV6AddressStr: String) throws {
		var sa6 = sockaddr_in6()
		sa6.sin6_family = sa_family_t(AF_INET6)
#if !os(Linux)
		sa6.sin6_len = __uint8_t(MemoryLayout<sockaddr_in6>.size)
#endif
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
#if !os(Linux)
		len = Int(sockaddrPtr.pointee.sa_len)
#endif
		family = sockaddrPtr.pointee.sa_family
#if !os(Linux)
		rawPointer = UnsafeMutableRawPointer.allocate(byteCount: len, alignment: MemoryLayout<sockaddr>.alignment /* Not sure about that though... */)
		rawPointer.copyMemory(from: rawsockaddr, byteCount: len)
#else
		rawPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<sockaddr>.size, alignment: MemoryLayout<sockaddr>.alignment /* Not sure about that though... */)
		rawPointer.copyMemory(from: rawsockaddr, byteCount: MemoryLayout<sockaddr>.size)
#endif
	}
	
	deinit {
		rawPointer.deallocate()
	}
	
	public func sockaddrStringRepresentation() throws -> String {
		let len = socklen_t(max(INET_ADDRSTRLEN, INET6_ADDRSTRLEN))
		var data = Data(capacity: Int(len))
		
		try data.withUnsafeMutableBytes{ (rwBuffer: UnsafeMutableRawBufferPointer) -> Void in
			let rwBuffer = rwBuffer.bindMemory(to: Int8.self).baseAddress!
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
		
		return try data.withUnsafeBytes{ (ccharBuffer: UnsafeRawBufferPointer) -> String in
			let ccharBuffer = ccharBuffer.bindMemory(to: CChar.self).baseAddress!
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
	
	public func hash(into hasher: inout Hasher) {
		/* Is this hash computation really wise?
		 * It is probably the safest way to do it, but I think we could go faster than converting the address to a String… */
		try? hasher.combine(sockaddrStringRepresentation())
	}
	
	public static func ==(lhs: SockAddrWrapper, rhs: SockAddrWrapper) -> Bool {
#if !os(Linux)
		guard lhs.len == rhs.len else {return false}
#endif
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
#if canImport(os)
				if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
					Conf.oslog.flatMap{ os_log("Got unknown family when comparing two SockAddrWrapper", log: $0, type: .error) }}
#endif
				Conf.logger?.error("Got unknown family when comparing two SockAddrWrapper")
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
#if canImport(os)
					if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
						Conf.oslog.flatMap{ os_log("Got unknown return value from inet_pton: %d. Treating as -1.", log: $0, type: .info, v) }}
#endif
					Conf.logger?.info("Got unknown return value from inet_pton: \(v). Treating as -1.")
				}
				throw SockAddrConversionError.systemError
		}
	}
	
}
