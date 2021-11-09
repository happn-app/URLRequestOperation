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
	
	struct KeyedContainer<K: CodingKey> {
		
		let data: MultipartFormData.Keyed
		let decoder: FormDataDecoder.Decoder
		
	}
	
}


extension FormDataDecoder.KeyedContainer: KeyedDecodingContainerProtocol {
	
	var allKeys: [K] {
		data.keys.compactMap(K.init(stringValue:))
	}
	
	var codingPath: [CodingKey] {
		decoder.codingPath
	}
	
	func contains(_ key: K) -> Bool {
		data.keys.contains(key.stringValue)
	}
	
	func getValue(forKey key: CodingKey) throws -> MultipartFormData {
		guard let value = data[key.stringValue] else {
			throw DecodingError.keyNotFound(
				key, .init(
					codingPath: codingPath,
					debugDescription: "No value associated with key \"\(key.stringValue)\"."
				)
			)
		}
		return value
	}
	
	func decodeNil(forKey key: K) throws -> Bool {
		false
	}
	
	func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
		try decoderForKey(key).decode()
	}
	
	func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
		try decoderForKey(key).container(keyedBy: keyType)
	}
	
	func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
		try decoderForKey(key).unkeyedContainer()
	}
	
	func superDecoder() throws -> Decoder {
		try decoderForKey(BasicCodingKey.super)
	}
	
	func superDecoder(forKey key: K) throws -> Decoder {
		try decoderForKey(key)
	}
	
	func decoderForKey(_ key: CodingKey) throws -> FormDataDecoder.Decoder {
		decoder.nested(at: key, with: try getValue(forKey: key))
	}
	
}
