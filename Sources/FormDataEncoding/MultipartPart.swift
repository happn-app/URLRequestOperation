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



/** A single part of a `multipart`-encoded message. */
public struct MultipartPart : Sendable, Equatable {
	
	/** The part’s headers. */
	public var headers: HTTPHeaders
	
	/** The part’s raw data. */
	public var body: Data
	
	/** Gets or sets the `name` attribute from the part’s `"Content-Disposition"` header. */
	public var name: String? {
		get {self.headers.getParameter("Content-Disposition", "name")}
		set {self.headers.setParameter("Content-Disposition", "name", to: newValue, defaultValue: "form-data")}
	}
	
	/**
	 Creates a new `MultipartPart`.
	 
	 ```
	 let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
	 ```
	 
	 - Parameter headers: The part’s headers.
	 - Parameter body: The part’s data. */
	public init(headers: HTTPHeaders = .init(), body: String) {
		self.init(headers: headers, body: Data(body.utf8))
	}
	
	/**
	 Creates a new `MultipartPart`.
	 
	 ```
	 let part = MultipartPart(headers: ["Content-Type": "text/plain"], body: "hello")
	 ```
	 
	 - Parameter headers: The part’s headers.
	 - Parameter body: The part’s data. */
	public init(headers: HTTPHeaders = .init(), body: Data) {
		self.headers = headers
		self.body = body
	}
	
}

/* **********************
   MARK: Array Extensions
   ********************** */

extension Array where Element == MultipartPart {
	
	/** Returns the first `MultipartPart` with matching name attribute in `"Content-Disposition"` header. */
	public func firstPart(named name: String) -> MultipartPart? {
		return first{ $0.name == name }
	}
	
	/** Returns all `MultipartPart`s with matching name attribute in `"Content-Disposition"` header. */
	public func allParts(named name: String) -> [MultipartPart] {
		return filter{ $0.name == name }
	}
}
