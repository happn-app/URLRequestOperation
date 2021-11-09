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

import Foundation



/**
 Encodes `Encodable` items to `multipart/form-data` encoded `Data`.
 
 See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
 
 See also ``MultipartParser`` for more information about the `multipart` encoding. */
public struct FormDataEncoder {
	
	/** Any contextual information set by the user for encoding. */
	public var userInfo: [CodingUserInfoKey: Any] = [:]
	
	/** Creates a new ``FormDataEncoder``. */
	public init() {
	}
	
	/**
	 Encodes an `Encodable` item to `String` using the supplied boundary.
	 
	 ```
	 let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
	 let data = try FormDataEncoder().encode(a, boundary: "123")
	 ```
	 
	 - Parameter encodable: Generic `Encodable` item.
	 - Parameter boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
	 - Throws: Any errors encoding the model with `Codable` or serializing the data.
	 - Returns: `multipart/form-data`-encoded `String`. */
	public func encode<E: Encodable>(_ encodable: E, boundary: String) throws -> Data {
		try MultipartSerializer().serialize(parts: parts(from: encodable), boundary: boundary)
	}
	
	/**
	 Encodes an `Encodable` item into a `ByteBuffer` using the supplied boundary.
	 
	 ```
	 let a = Foo(string: "a", int: 42, double: 3.14, array: [1, 2, 3])
	 var buffer = ByteBuffer()
	 let data = try FormDataEncoder().encode(a, boundary: "123", into: &buffer)
	 ```
	 
	 - Parameter encodable: Generic `Encodable` item.
	 - Parameter boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
	 - Parameter buffer: Buffer to write to.
	 - Throws: Any errors encoding the model with `Codable` or serializing the data. */
	public func encode<E: Encodable>(_ encodable: E, boundary: String, into stream: OutputStream) throws {
		try MultipartSerializer().serialize(parts: parts(from: encodable), boundary: boundary, into: stream)
	}
	
	private func parts<E: Encodable>(from encodable: E) throws -> [MultipartPart] {
		let encoder = Encoder(codingPath: [], userInfo: userInfo)
		try encodable.encode(to: encoder)
		return encoder.storage.data?.namedParts() ?? []
	}
	
}
