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
	
	struct Decoder {
		
		let codingPath: [CodingKey]
		let data: MultipartFormData
		let userInfo: [CodingUserInfoKey: Any]
		
	}
	
}


extension FormDataDecoder.Decoder : Decoder {
	
	func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
		guard let dictionary = data.dictionary else {
			throw decodingError(expectedType: "dictionary")
		}
		return KeyedDecodingContainer(FormDataDecoder.KeyedContainer(data: dictionary, decoder: self))
	}
	
	func unkeyedContainer() throws -> UnkeyedDecodingContainer {
		guard let array = data.array else {
			throw decodingError(expectedType: "array")
		}
		return FormDataDecoder.UnkeyedContainer(data: array, decoder: self)
	}
	
	func singleValueContainer() throws -> SingleValueDecodingContainer {
		self
	}
	
}

extension FormDataDecoder.Decoder {
	
	func nested(at key: CodingKey, with data: MultipartFormData) -> Self {
		.init(codingPath: codingPath + [key], data: data, userInfo: userInfo)
	}
	
}


private extension FormDataDecoder.Decoder {
	
	func decodingError(expectedType: String) -> Error {
		let encounteredType: Any.Type
		let encounteredTypeDescription: String
		
		switch data {
			case .nestingDepthExceeded:
				return DecodingError.dataCorrupted(.init(
					codingPath: codingPath,
					debugDescription: "Nesting depth exceeded while expecting \(expectedType).",
					underlyingError: nil
				))
			case .array:
				encounteredType = [MultipartFormData].self
				encounteredTypeDescription = "array"
			case .keyed:
				encounteredType = MultipartFormData.Keyed.self
				encounteredTypeDescription = "dictionary"
			case .single:
				encounteredType = MultipartPart.self
				encounteredTypeDescription = "single value"
		}
		
		return DecodingError.typeMismatch(
			encounteredType,
			.init(
				codingPath: codingPath,
				debugDescription: "Expected \(expectedType) but encountered \(encounteredTypeDescription).",
				underlyingError: nil
			)
		)
	}
	
}
