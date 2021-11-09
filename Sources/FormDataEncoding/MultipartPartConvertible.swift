/* From https://github.com/vapor/multipart-kit, 2dd9368a3c9580792b77c7ef364f3735909d9996
 * Original License:
 *    The MIT License (MIT)
 *
 *    Copyright (c) 2018 Qutheory, LLC
 *
 *    Permission is hereby granted, free of charge, to any person obtaining a copy
 *    of this software and associated documentation files (the "Software"), to deal
 *    in the Software without restriction, including without limitation the rights
 *    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *    copies of the Software, and to permit persons to whom the Software is
 *    furnished to do so, subject to the following conditions:
 *
 *    The above copyright notice and this permission notice shall be included in all
 *    copies or substantial portions of the Software.
 *
 *    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *    SOFTWARE.
 */

import struct Foundation.Data
import struct Foundation.UUID



public protocol MultipartPartConvertible {
	
	var multipart: MultipartPart? {get}
	init?(multipart: MultipartPart)
	
}


extension MultipartPart : MultipartPartConvertible {
	
	public var multipart: MultipartPart? {
		return self
	}
	
	public init?(multipart: MultipartPart) {
		self = multipart
	}
	
}


extension String : MultipartPartConvertible {
	
	public var multipart: MultipartPart? {
		return MultipartPart(body: self)
	}
	
	public init?(multipart: MultipartPart) {
		self.init(data: multipart.body, encoding: .utf8)
	}
	
}


extension FixedWidthInteger {
	
	public var multipart: MultipartPart? {
		return MultipartPart(body: String(self))
	}
	
	public init?(multipart: MultipartPart) {
		guard let string = String(multipart: multipart) else {
			return nil
		}
		self.init(string)
	}
	
}


extension Int    : MultipartPartConvertible {}
extension Int8   : MultipartPartConvertible {}
extension Int16  : MultipartPartConvertible {}
extension Int32  : MultipartPartConvertible {}
extension Int64  : MultipartPartConvertible {}
extension UInt   : MultipartPartConvertible {}
extension UInt8  : MultipartPartConvertible {}
extension UInt16 : MultipartPartConvertible {}
extension UInt32 : MultipartPartConvertible {}
extension UInt64 : MultipartPartConvertible {}


extension Float : MultipartPartConvertible {
	
	public var multipart: MultipartPart? {
		return MultipartPart(body: String(self))
	}
	
	public init?(multipart: MultipartPart) {
		guard let string = String(multipart: multipart) else {
			return nil
		}
		self.init(string)
	}
	
}


extension Double : MultipartPartConvertible {
	
	public var multipart: MultipartPart? {
		return MultipartPart(body: String(self))
	}
	
	public init?(multipart: MultipartPart) {
		guard let string = String(multipart: multipart) else {
			return nil
		}
		self.init(string)
	}
	
}


extension Bool : MultipartPartConvertible {
	
	public var multipart: MultipartPart? {
		return MultipartPart(body: String(self))
	}
	
	public init?(multipart: MultipartPart) {
		guard let string = String(multipart: multipart) else {
			return nil
		}
		self.init(string)
	}
	
}


extension Data : MultipartPartConvertible {
	
	public var multipart: MultipartPart? {
		return MultipartPart(body: self)
	}
	
	public init?(multipart: MultipartPart) {
		self.init(multipart.body)
	}
	
}
