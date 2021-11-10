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

import StreamReader



/**
 Decodes `Decodable` types from `multipart/form-data` encoded `Data`.
 
 See [RFC#2388](https://tools.ietf.org/html/rfc2388) for more information about `multipart/form-data` encoding.
 
 See also `MultipartParser` for more information about the `multipart` encoding. */
public struct FormDataDecoder {
	
	/**
	 Maximum nesting depth to allow when decoding the input.
	 
	 - 1 corresponds to a single value;
	 - 2 corresponds to an an object with non-nested properties or an 1 dimensional array;
	 - 3… corresponds to nested objects or multi-dimensional arrays or combinations thereof. */
	let nestingDepth: Int
	
	/** Any contextual information set by the user for decoding. */
	public var userInfo: [CodingUserInfoKey: Any] = [:]
	
	/**
	 Creates a new `FormDataDecoder`.
	 
	 - Parameter nestingDepth: maximum allowed nesting depth of the decoded structure. Defaults to 8. */
	public init(nestingDepth: Int = 8) {
		self.nestingDepth = nestingDepth
	}
	
	/**
	 Decodes a `Decodable` item from `String` using the supplied boundary.
	 
	 ```
	 let foo = try FormDataDecoder().decode(Foo.self, from: "...", boundary: "123")
	 ```
	 
	 - Parameter decodable: Generic `Decodable` type.
	 - Parameter data: String to decode.
	 - Parameter boundary: Multipart boundary to used in the decoding.
	 - Throws: Any errors decoding the model with `Codable` or parsing the data.
	 - Returns: An instance of the decoded type `D`. */
	public func decode<D: Decodable>(_ decodable: D.Type, from data: String, boundary: String) throws -> D {
		try decode(D.self, from: DataReader(data: Data(data.utf8)), boundary: boundary)
	}
	
	/**
	 Decodes a `Decodable` item from `Data` using the supplied boundary.
	 
	 ```
	 let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
	 ```
	 
	 - Parameter decodable: Generic `Decodable` type.
	 - Parameter data: Data to decode.
	 - Parameter boundary: Multipart boundary to used in the decoding.
	 - Throws: Any errors decoding the model with `Codable` or parsing the data.
	 - Returns: An instance of the decoded type `D`. */
	public func decode<D: Decodable>(_ decodable: D.Type, from data: Data, boundary: String) throws -> D {
		try decode(D.self, from: DataReader(data: data), boundary: boundary)
	}
	
	/**
	 Decodes a `Decodable` item from `Data` using the supplied boundary.
	
	 ```
	 let foo = try FormDataDecoder().decode(Foo.self, from: data, boundary: "123")
	 ```
	 
	 - Parameter decodable: Generic `Decodable` type.
	 - Parameter data: Data to decode.
	 - Parameter boundary: Multipart boundary to used in the decoding.
	 - Throws: Any errors decoding the model with `Codable` or parsing the data.
	 - Returns: An instance of the decoded type `D`. */
	public func decode<D: Decodable>(_ decodable: D.Type, from stream: StreamReader, boundary: String) throws -> D {
		let parser = MultipartParser(boundary: boundary)
		let data = MultipartFormData(parts: try parser.parse(stream), nestingDepth: nestingDepth)
		let decoder = Decoder(codingPath: [], data: data, userInfo: userInfo)
		return try decoder.decode()
	}
	
}
