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
 Parses multipart-encoded `Data` into `MultipartPart`s.
 Multipart encoding is a widely-used format for encoding web-form data that includes rich content like files.
 It allows for arbitrary data to be encoded in each part thanks to a unique delimiter "boundary" that is defined separately.
 This boundary is guaranteed by the client to not appear anywhere in the data.
 
 `multipart/form-data` is a special case of `multipart` encoding where each part contains a `Content-Disposition` header and name.
 This is used by the `FormDataEncoder` and `FormDataDecoder` to convert `Codable` types to/from multipart data.
 
 See [Wikipedia](https://en.wikipedia.org/wiki/MIME#Multipart_messages) for more information.
 
 See also `form-urlencoded` encoding where delimiter boundaries are not required. */
public final class MultipartParser {
	
	public let boundary: Data
	private let newLineAndBoundary: Data
	
	/**
	 Creates a new `MultipartParser`.
	 
	 - Parameter boundary: boundary separating parts.
	 Must not be empty nor longer than 70 characters according to rfc1341 but we don't check for the latter. */
	public init(boundary: String) {
		precondition(!boundary.isEmpty)
		self.boundary = Self.twoHyphens + Data(boundary.utf8)
		self.newLineAndBoundary = Self.crlf + self.boundary
	}
	
	public func parse(_ string: String) throws -> [MultipartPart] {
		return try parse(DataReader(data: Data(string.utf8)))
	}
	
	public func parse(_ bytes: [UInt8]) throws -> [MultipartPart] {
		return try parse(DataReader(data: Data(bytes)))
	}
	
	/**
	 Parse the given stream.
	 
	 The stream next read will start at the beginning of the epilogue when this method is successful. */
	public func parse(_ streamReader: StreamReader, ignoreAdditionalData: Bool = false) throws -> [MultipartPart] {
		var res = [MultipartPart]()
		/* Read preamble first. Usually empty. Ignored (as per RFC 1341). */
		_ = try streamReader.readData(upTo: [boundary], matchingMode: .anyMatchWins, includeDelimiter: true)
		while try readAfterEndOfPart(streamReader) {
			/* Read the headers */
			var headers = HTTPHeaders()
			while let line = try readHeaderLine(streamReader) {
				let split = line.split(separator: 0x3a/*:*/, maxSplits: 1, omittingEmptySubsequences: false)
				guard split.count == 2 else {
					assert(split.count == 1)
					throw Err.syntaxErrorInSerializedMultipart
				}
				/* What is valid in an HTTP Header value?
				 *
				 * Apparently, historically an HTTP header _could_ “line fold” and spread over multiple lines.
				 * We do not support that (and it is obsoleted in RFC 7230, in 2014).
				 *
				 * Also, historically, 0x80-FF was allowed in the value.
				 * We do not support that either.
				 *
				 * We only allow VCHARs (any visible US-ASCII character, aka. 0x21...7E), space and tabs, and trim space and tabs (RFC 7230 § 3.2). */
				guard
					!split[0].isEmpty,
					split[0].first(where: { !$0.isAllowedHeaderFieldNameCharacter }) == nil,
					split[1].first(where: { ($0 < 0x20 || $0 > 0x7E) && $0 != 0x09/*tab*/ }) == nil,
					let name = String(data: split[0], encoding: .ascii),
					let value = String(data: split[1], encoding: .ascii)
				else {
					throw Err.syntaxErrorInSerializedMultipart
				}
				headers.add(name: name, value: value.trimmingCharacters(in: CharacterSet(charactersIn: " \t")))
			}
			let body = try streamReader.readData(upTo: [newLineAndBoundary], matchingMode: .anyMatchWins, includeDelimiter: false)
			_ = try streamReader.readData(size: body.delimiter.count)
			res.append(MultipartPart(headers: headers, body: body.data))
		}
		/* Read the CRLF after the end of last part to go to beginning of epilogue. */
		guard try streamReader.readData(size: Self.crlf.count) == Self.crlf else {
			throw Err.syntaxErrorInSerializedMultipart
		}
		return res
	}
	
	/** Returns true if more parts are to be expected, false otherwise. Throws in case of syntax error. */
	private func readAfterEndOfPart(_ streamReader: StreamReader) throws -> Bool {
		assert(Self.crlf.count == 2)
		assert(Self.twoHyphens.count == 2)
		switch try streamReader.readData(size: 2) {
			case Self.crlf:       return true
			case Self.twoHyphens: return false
			default: throw Err.syntaxErrorInSerializedMultipart
		}
	}
	
	private func readHeaderLine(_ streamReader: StreamReader) throws -> Data? {
		guard let (line, newline) = try streamReader.readLine(allowUnixNewLines: false, allowLegacyMacOSNewLines: false, allowWindowsNewLines: true) else {
			throw Err.syntaxErrorInSerializedMultipart
		}
		guard newline == Self.crlf else {
			throw Err.syntaxErrorInSerializedMultipart
		}
		return !line.isEmpty ? line : nil
	}
	
	private static let crlf = Data("\r\n".utf8)
	private static let twoHyphens = Data("--".utf8)
	
}


private extension UInt8 {
	
	/*
	 * See https://tools.ietf.org/html/rfc1341#page-6 and https://tools.ietf.org/html/rfc822#section-3.2
	 *
	 * field-name  = token
	 * token       = 1*<any CHAR except CTLs or tspecials>
	 * CTL         = <any US-ASCII control character (octets 0 - 31) and DEL (127)>
	 * tspecials   = "(" | ")" | "<" | ">" | "@"
	 *             | "," | ";" | ":" | "\" | DQUOTE
	 *             | "/" | "[" | "]" | "?" | "="
	 *             | "{" | "}" | SP | HT
	 * DQUOTE      = <US-ASCII double-quote mark (34)>
	 * SP          = <US-ASCII SP, space (32)>
	 * HT          = <US-ASCII HT, horizontal-tab (9)>
	 */
	private static let allowedHeaderFieldNameCharacterFlags: [Bool] = [
	/* 0 nul   1 soh   2 stx   3 etx   4 eot   5 enq   6 ack   7 bel */
		false,  false,  false,  false,  false,  false,  false,  false,
	/* 8 bs    9 ht    10 nl   11 vt   12 np   13 cr   14 so   15 si */
		false,  false,  false,  false,  false,  false,  false,  false,
	/* 16 dle  17 dc1  18 dc2  19 dc3  20 dc4  21 nak  22 syn  23 etb */
		false,  false,  false,  false,  false,  false,  false,  false,
	/* 24 can  25 em   26 sub  27 esc  28 fs   29 gs   30 rs   31 us */
		false,  false,  false,  false,  false,  false,  false,  false,
	/* 32 sp   33 !    34 "    35 #    36 $    37 %    38 &    39 ' */
		false,  true,   false,  true,   true,   true,   true,   true,
	/* 40 (    41 )    42 *    43 +    44 ,    45 -    46 .    47 / */
		false,  false,  true,   true,   false,  true,   true,   false,
	/* 48 0    49 1    50 2    51 3    52 4    53 5    54 6    55 7 */
		true,   true,   true,   true,   true,   true,   true,   true,
	/* 56 8    57 9    58 :    59 ;    60 <    61 =    62 >    63 ? */
		true,   true,   false,  false,  false,  false,  false,  false,
	/* 64 @    65 A    66 B    67 C    68 D    69 E    70 F    71 G */
		false,  true,   true,   true,   true,   true,   true,   true,
	/* 72 H    73 I    74 J    75 K    76 L    77 M    78 N    79 O */
		true,   true,   true,   true,   true,   true,   true,   true,
	/* 80 P    81 Q    82 R    83 S    84 T    85 U    86 V    87 W */
		true,   true,   true,   true,   true,   true,   true,   true,
	/* 88 X    89 Y    90 Z    91 [    92 \    93 ]    94 ^    95 _ */
		true,   true,   true,    false, false,  false,  true,   true,
	/* 96 `    97 a    98 b    99 c    100 d   101 e   102 f   103 g */
		true,   true,   true,   true,   true,   true,   true,   true,
	/* 104 h   105 i   106 j   107 k   108 l   109 m   110 n   111 o */
		true,   true,   true,   true,   true,   true,   true,   true,
	/* 112 p   113 q   114 r   115 s   116 t   117 u   118 v   119 w */
		true,   true,   true,   true,   true,   true,   true,   true,
	/* 120 x   121 y   122 z   123 {   124 |   125 }   126 ~   127 del */
		true,   true,   true,   false,  true,   false,  true,   false
	]
	
	var isAllowedHeaderFieldNameCharacter: Bool {
		Self.allowedHeaderFieldNameCharacterFlags[Int(self)]
	}
	
}
