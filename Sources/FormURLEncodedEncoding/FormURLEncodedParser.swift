/* From https://github.com/vapor/vapor, 68233685fd1a943e8772634e02abfec076dcb8f4
 * Original License:
 *    The MIT License (MIT)
 *
 *    Copyright (c) 2020 Qutheory, LLC
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



/** Parses a URL Query `single=value&arr=1&arr=2&obj[key]=objValue` into */
internal struct FormURLEncodedParser {
	
	init() {}
	
	func parse(_ query: String) throws -> URLEncodedFormData {
		let plusDecodedQuery = query.replacingOccurrences(of: "+", with: "%20")
		var result: URLEncodedFormData = []
		for pair in plusDecodedQuery.split(separator: "&") {
			let kv = pair.split(
				separator: "=",
				maxSplits: 1, /* max 1, `foo=a=b` should be `"foo": "a=b"` */
				omittingEmptySubsequences: false
			)
			switch kv.count {
				case 1:
					let value = String(kv[0])
					result.set(value: .urlEncoded(value), forPath: [])
				case 2:
					let key = kv[0]
					let value = String(kv[1])
					result.set(value: .urlEncoded(value), forPath: try parseKey(key: Substring(key)))
				default:
					/* Empty `&&` */
					continue
			}
		}
		return result
	}
	
	func parseKey(key: Substring) throws -> [String] {
		guard let percentDecodedKey = key.removingPercentEncoding else {
			throw Err.malformedKey(key: key)
		}
		return try percentDecodedKey.split(separator: "[").enumerated().map { (i, part) in
			switch i {
				case 0:
					return String(part)
				default:
					guard part.last == "]" else {
						throw Err.malformedKey(key: key)
					}
					return String(part.dropLast())
			}
		}
	}
	
}
