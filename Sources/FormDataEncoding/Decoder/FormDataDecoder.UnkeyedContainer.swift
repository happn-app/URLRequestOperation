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



extension FormDataDecoder {
	
	struct UnkeyedContainer {
		
		var currentIndex: Int = 0
		let data: [MultipartFormData]
		let decoder: FormDataDecoder.Decoder
		
	}
	
}


extension FormDataDecoder.UnkeyedContainer: UnkeyedDecodingContainer {
	
	var codingPath: [CodingKey] {
		decoder.codingPath
	}
	var count: Int? { data.count }
	var index: CodingKey { BasicCodingKey.index(currentIndex) }
	var isAtEnd: Bool { currentIndex >= data.count }
	
	mutating func decodeNil() throws -> Bool {
		false
	}
	
	mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
		try decoderAtIndex().decode(T.self)
	}
	
	mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
		try decoderAtIndex().container(keyedBy: keyType)
	}
	
	mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
		try decoderAtIndex().unkeyedContainer()
	}
	
	mutating func superDecoder() throws -> Decoder {
		try decoderAtIndex()
	}
	
	mutating func decoderAtIndex() throws -> FormDataDecoder.Decoder {
		defer {currentIndex += 1}
		return try decoder.nested(at: index, with: getValue())
	}
	
	mutating func getValue() throws -> MultipartFormData {
		guard !isAtEnd else {
			throw DecodingError.valueNotFound(
				FormDataDecoder.Decoder.self,
				.init(
					codingPath: codingPath,
					debugDescription: "Unkeyed container is at end.",
					underlyingError: nil
				)
			)
		}
		return data[currentIndex]
	}
	
}
