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
 Serializes ``MultipartForm``s to `Data`.
 
 See ``MultipartParser`` for more information about the multipart encoding. */
public final class MultipartSerializer {
	
	/** Creates a new ``MultipartSerializer``. */
	public init() {
	}
	
	/**
	 Serializes the ``MultipartForm`` to data.
	 
	 ```
	 let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
	 print(data) /* multipart-encoded */
	 ```
	 
	 - Parameter parts: One or more `MultipartPart`s to serialize into `Data`.
	 - Parameter boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
	 - Throws: Any errors that may occur during serialization.
	 - Returns: `multipart`-encoded `Data`. */
	public func serialize(parts: [MultipartPart], boundary: String) throws -> Data {
		let stream = OutputStream(toMemory: ())
		stream.open(); defer {stream.close()}
		
		try serialize(parts: parts, boundary: boundary, into: stream)
		guard let nsdata = stream.property(forKey: .dataWrittenToMemoryStreamKey) as? NSData else {
			throw Err.internalError
		}
		
		return Data(referencing: nsdata)
	}
	
	/**
	 Serializes the `MultipartForm` into a `ByteBuffer`.
	 
	 ```
	 var buffer = ByteBuffer()
	 try MultipartSerializer().serialize(parts: [part], boundary: "123", into: &buffer)
	 print(String(buffer: buffer)) // multipart-encoded
	 ```
	 
	 - Parameter parts: One or more `MultipartPart`s to serialize into `Data`.
	 - Parameter boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
	 - Parameter buffer: Buffer to write to.
	 - Throws: Any errors that may occur during serialization. */
	public func serialize(parts: [MultipartPart], boundary: String, into buffer: OutputStream) throws {
		for part in parts {
			try buffer.writeString("--")
			try buffer.writeString(boundary)
			try buffer.writeString("\r\n")
			for (key, val) in part.headers {
				try buffer.writeString(key)
				try buffer.writeString(": ")
				try buffer.writeString(val)
				try buffer.writeString("\r\n")
			}
			try buffer.writeString("\r\n")
			try buffer.writeData(part.body)
			try buffer.writeString("\r\n")
		}
		try buffer.writeString("--")
		try buffer.writeString(boundary)
		try buffer.writeString("--\r\n")
	}
	
}


extension OutputStream {
	
	func write(allOf bytes: UnsafePointer<UInt8>, count: Int) throws {
		var bytes = bytes
		var count = count
		while count > 0 {
			let n = write(bytes, maxLength: count)
			assert(n <= count)
			
			guard n > 0 else {
				throw Err.cannotWriteToStream(streamError)
			}
			
			count -= n
			bytes = bytes.advanced(by: n)
		}
	}
	
	func writeData(_ data: Data) throws {
		try data.withUnsafeBytes{ bytes in
			let boundBytes = bytes.bindMemory(to: UInt8.self)
			guard !boundBytes.isEmpty else {return}
			
			try write(allOf: boundBytes.baseAddress! /* !-safe because not empty */, count: boundBytes.count)
		}
	}
	
	func writeString(_ str: String) throws {
		var str = str
		try str.withUTF8{ bytes in
			guard !bytes.isEmpty else {return}
			try write(allOf: bytes.baseAddress! /* !-safe because not empty */, count: bytes.count)
		}
	}
	
}
