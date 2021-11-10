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



/* All of this is straight from MultiPartKit 2dd9368a3c9580792b77c7ef364f3735909d9996
 * TODO: Check if parsing is correct (I’m not quite certain the RFCs are followed). */
extension HTTPHeaders {
	
	func getParameter(_ name: String, _ key: String) -> String? {
		return self.headerParts(name: name).flatMap {
			$0.filter{ $0.hasPrefix("\(key)=") }
			.first?
			.split(separator: "=")
			.last
			.flatMap{ $0.trimmingCharacters(in: .quotes)}
		}
	}
	
	mutating func setParameter(
		_ name: String,
		_ key: String,
		to value: String?,
		defaultValue: String
	) {
		var current: [String]
		if let existing = self.headerParts(name: name) {
			current = existing.filter{ !$0.hasPrefix("\(key)=") }
		} else {
			current = [defaultValue]
		}
		if let value = value {
			current.append("\(key)=\"\(value)\"")
		}
		let new = current.joined(separator: "; ")
			.trimmingCharacters(in: .whitespaces)
		self.replaceOrAdd(name: name, value: new)
	}
	
	func headerParts(name: String) -> [String]? {
		return self[name]
			.first
			.flatMap{
				$0.split(separator: ";")
					.map{ $0.trimmingCharacters(in: .whitespaces) }
			}
	}
}


extension CharacterSet {
	
	static var quotes: CharacterSet {
		return .init(charactersIn: #""'"#)
	}
	
}
