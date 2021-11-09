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



extension FormDataEncoder {
	
	struct KeyedContainer<Key: CodingKey> {
		
		let dataContainer = KeyedDataContainer()
		let encoder: Encoder
		
	}
	
}


extension FormDataEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
	
	var codingPath: [CodingKey] {
		encoder.codingPath
	}
	
	func encodeNil(forKey _: Key) throws {
		/* skip */
	}
	
	func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
		try encoderForKey(key).encode(value)
	}
	
	func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
		encoderForKey(key).container(keyedBy: keyType)
	}
	
	func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
		encoderForKey(key).unkeyedContainer()
	}
	
	func superEncoder() -> Encoder {
		encoderForKey(BasicCodingKey.super)
	}
	
	func superEncoder(forKey key: Key) -> Encoder {
		encoderForKey(key)
	}
	
	func encoderForKey(_ key: CodingKey) -> FormDataEncoder.Encoder {
		let encoder = self.encoder.nested(at: key)
		dataContainer.value[key.stringValue] = encoder.storage
		return encoder
	}
	
}
