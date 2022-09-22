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

@preconcurrency import OrderedCollections



enum MultipartFormData : Sendable, Equatable {
	
	typealias Keyed = OrderedDictionary<String, MultipartFormData>
	
	case single(MultipartPart)
	case array([MultipartFormData])
	case keyed(Keyed)
	case nestingDepthExceeded
	
	init(parts: [MultipartPart], nestingDepth: Int) {
		self = parts.reduce(into: .empty) { result, part in
			result.insert(
				part,
				at: part.name.map(makePath) ?? [],
				remainingNestingDepth: nestingDepth
			)
		}
	}
	
	static let empty = MultipartFormData.keyed([:])
	
	var array: [MultipartFormData]? {
		guard case let .array(array) = self else { return nil }
		return array
	}
	
	var dictionary: Keyed? {
		guard case let .keyed(dict) = self else { return nil }
		return dict
	}
	
	var part: MultipartPart? {
		guard case let .single(part) = self else { return nil }
		return part
	}
	
	var hasExceededNestingDepth: Bool {
		guard case .nestingDepthExceeded = self else {
			return false
		}
		return true
	}
	
}


private func makePath(from string: String) -> ArraySlice<Substring> {
	ArraySlice(string.replacingOccurrences(of: "]", with: "").split(omittingEmptySubsequences: false) { $0 == "[" })
}


extension MultipartFormData {
	
	func namedParts() -> [MultipartPart] {
		Self.namedParts(from: self)
	}
	
	private static func namedParts(from data: MultipartFormData, path: String? = nil) -> [MultipartPart] {
		switch data {
			case .array(let array):
				return array.enumerated().flatMap { offset, element in
					namedParts(from: element, path: path.map { "\($0)[\(offset)]" }) }
			case .single(var part):
				part.name = path
				return [part]
			case .keyed(let dictionary):
				return dictionary.flatMap { key, value in
					namedParts(from: value, path: path.map { "\($0)[\(key)]" } ?? key)
				}
			case .nestingDepthExceeded:
				return []
		}
	}
	
}


private extension MultipartFormData {
	
	mutating func insert(_ part: MultipartPart, at path: ArraySlice<Substring>, remainingNestingDepth: Int) {
		self = inserting(part, at: path, remainingNestingDepth: remainingNestingDepth)
	}
	
	func inserting(_ part: MultipartPart, at path: ArraySlice<Substring>, remainingNestingDepth: Int) -> MultipartFormData {
		guard let head = path.first else {
			return .single(part)
		}
		
		guard remainingNestingDepth > 1 else {
			return .nestingDepthExceeded
		}
		
		func insertPart(into data: inout MultipartFormData) {
			data.insert(part, at: path.dropFirst(), remainingNestingDepth: remainingNestingDepth - 1)
		}
		
		func insertingPart(at index: Int?) -> MultipartFormData {
			var array = self.array ?? []
			let count = array.count
			let index = index ?? count
			
			switch index {
				case count:
					array.append(.empty)
				case 0..<count:
					break
				default:
					/* ignore indices outside the range of 0...count */
					return self
			}
			
			insertPart(into: &array[index])
			return .array(array)
		}
		
		if head.isEmpty {
			return insertingPart(at: nil)
		} else if let index = Int(head) {
			return insertingPart(at: index)
		} else {
			var dictionary = self.dictionary ?? [:]
			insertPart(into: &dictionary[String(head), default: .empty])
			return .keyed(dictionary)
		}
	}
	
}
