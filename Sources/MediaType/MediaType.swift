/*
Copyright 2021 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



/** Represent a media type ([RFC 7231, section 3.1.1.1](https://datatracker.ietf.org/doc/html/rfc7231#section-3.1.1.1)). */
public struct MediaType : Sendable, Hashable, RawRepresentable {
	
	public typealias RawValue = String
	
	public struct Parameter : Sendable, Hashable {
		
		var key: String
		var value: String
		
		public func hash(into hasher: inout Hasher) {
			hasher.combine(key.lowercased())
			hasher.combine(value)
		}
		
		public static func ==(_ lhs: Parameter, _ rhs: Parameter) -> Bool {
			return lhs.key.lowercased() == rhs.key.lowercased() && lhs.value == rhs.value
		}
		
	}
	
	public var type: String
	public var subtype: String
	
	public var parameters: [Parameter]
	
	/**
	 Parse a media type.
	 
	 - Important: We do not allow obs-text chars in parameter values (%x80-FF) even thought the RFC does.
	 The rationale for this is `String` works with grapheme clusters and not bytes.
	 We cannot access the original bytes in the media-type!
	 So we simply do not allow obs-text in quoted strings.
	 RFC says parser should not allow them anymore anyway. */
	public init?(rawValue: String) {
		/* Syntax (from https://datatracker.ietf.org/doc/html/rfc7231#section-3.1.1.1):
		 * media-type = type "/" subtype *( OWS ";" OWS parameter )
		 * type       = token
		 * subtype    = token
		 * parameter  = token "=" ( token / quoted-string )
		 *
		 * From https://datatracker.ietf.org/doc/html/rfc7230#section-3.2.6 we have:
		 * token          = 1*tchar
		 * tchar          = "!" / "#" / "$" / "%" / "&" / "'" / "*"
		 *                / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
		 *                / DIGIT / ALPHA
		 *                ; any VCHAR, except delimiters
		 * quoted-string  = DQUOTE *( qdtext / quoted-pair ) DQUOTE
		 * qdtext         = HTAB / SP / %x21 / %x23-5B / %x5D-7E / obs-text
		 * obs-text       = %x80-FF
		 * quoted-pair    = "\" ( HTAB / SP / VCHAR / obs-text )
		 */
		let scanner = Scanner(string: rawValue)
		scanner.charactersToBeSkipped = CharacterSet() /* We skip nothing */
		
		guard let typeParsed = scanner.mt_scanCharacters(from: .tchar) else {return nil}
		assert(!typeParsed.isEmpty)
		self.type = typeParsed
		
		guard scanner.mt_scanString("/") != nil else {return nil}
		
		guard let subtypeParsed = scanner.mt_scanCharacters(from: .tchar) else {return nil}
		assert(!subtypeParsed.isEmpty)
		self.subtype = subtypeParsed
		
		var parameters = [Parameter]()
		while !scanner.isAtEnd {
			_ = scanner.mt_scanCharacters(from: .ws)
			guard scanner.mt_scanString(";") != nil else {return nil}
			_ = scanner.mt_scanCharacters(from: .ws)
			
			guard let keyParsed = scanner.mt_scanCharacters(from: .tchar) else {return nil}
			assert(!keyParsed.isEmpty)
			let key = keyParsed
			
			guard scanner.mt_scanString("=") != nil else {return nil}
			
			let value: String
			if scanner.mt_scanString("\"") != nil {
				/* We must parse a quoted string */
				guard let v = Self.parseQuotedString(from: scanner) else {return nil}
				value = v
			} else {
				guard let valueParsed = scanner.mt_scanCharacters(from: .tchar) else {return nil}
				assert(!valueParsed.isEmpty)
				value = valueParsed
			}
			
			parameters.append(Parameter(key: key, value: value))
		}
		assert(scanner.isAtEnd)
		
		self.parameters = parameters
	}
	
	public var rawValue: String {
		return type.lowercased() + "/" + subtype.lowercased() + parameters.reduce("", { $0 + ";" + $1.key.lowercased() + "=" + $1.value.quotedIfNeeded() })
	}
	
	public subscript(_ parameterKey: String) -> String? {
		return parameter(forKey: parameterKey)
	}
	
	public func parameter(forKey parameterKey: String) -> String? {
		return parameters.map{ (key: $0.key, value: $0.value) }.last{ $0.key.lowercased() == parameterKey.lowercased() }?.value
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(type.lowercased())
		hasher.combine(subtype.lowercased())
		hasher.combine(parameters)
	}
	
	public static func ==(_ lhs: MediaType, _ rhs: MediaType) -> Bool {
		return lhs.type.lowercased() == rhs.type.lowercased() && lhs.subtype.lowercased() == rhs.subtype.lowercased() && lhs.parameters == rhs.parameters
	}
	
	/* Copy-pasted from https://github.com/Frizlab/LinkHeaderParser/blob/f4c241cf9609dec9bc8727671669e5c99a0a094e/Sources/LinkHeaderParser/LinkHeaderParser.swift */
	private static func parseQuotedString(from scanner: Scanner, currentlyParsed: String = "") -> String? {
		var parsedString = currentlyParsed
		
		/* Let’s try and parse whatever legal characters we can from the quoted string.
		 * The backslash and double-quote chars are not in the set we parse here, so the scanner will stop at these (among other). */
		if let scanned = scanner.mt_scanCharacters(from: .qdtext) {
			parsedString += scanned
		}
		
		/* Now let’s see if we stopped at a backlash.
		 * If so, we’ll retrieve the next char, verify it is in the legal charset for a backslashed char,
		 * add it to the parsed string, and continue parsing the quoted string from there. */
		guard scanner.mt_scanString("\\") == nil else {
			guard !scanner.isAtEnd else {return nil}
			
			/* Whatever char we have at the current location will be added to the parsed string (if in quotedPairSecondCharCharacterSet).
			 * We have to do ObjC-index to Swift index conversion though… */
			
			let addedStr = String(scanner.string[scanner.mt_currentIndex])
			scanner.scanLocation += 1
			
			guard addedStr.rangeOfCharacter(from: .quotedPairSecondChar) != nil else {return nil}
			parsedString += addedStr
			
			return parseQuotedString(from: scanner, currentlyParsed: parsedString)
		}
		
		/* We have now consumed all legal chars from a quoted string and are not stopped on a backslash.
		 * The only legal char left is a double quote!
		 * Which also signals the end of the quoted string. */
		guard scanner.mt_scanString("\"") != nil else {return nil}
		return parsedString
	}
	
}


internal extension String {
	
	func quotedIfNeeded() -> String {
		var quote = ""
		var escaped = self
		var range = escaped.startIndex..<escaped.endIndex
		while let found = escaped.rangeOfCharacter(from: .qdtext.inverted, options: .backwards, range: range) {
			quote = #"""#
			escaped.replaceSubrange(found, with: "\\" + escaped[found])
			range = escaped.startIndex..<found.lowerBound
		}
		
		return quote + escaped + quote
	}
	
}


internal extension CharacterSet {
	
	static let sp = CharacterSet(charactersIn: " ")
	static let htab = CharacterSet(charactersIn: "\t")
	
	static let ws = sp.union(htab)
	
	static let digit = CharacterSet(charactersIn: "0123456789")
	static let alpha = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	static let tchar = CharacterSet(charactersIn: "!#$%&'*+-.^_`|~").union(digit).union(alpha)
	
	static let qdtext = ws
		.union(CharacterSet(arrayLiteral: Unicode.Scalar(0x21)))
		.union(CharacterSet(charactersIn: Unicode.Scalar(0x23)...Unicode.Scalar(0x5b)))
		.union(CharacterSet(charactersIn: Unicode.Scalar(0x5d)...Unicode.Scalar(0x7e)))
		/* no obs-text */
	static let quotedPairSecondChar = ws
		.union(CharacterSet(charactersIn: Unicode.Scalar(0x21)...Unicode.Scalar(0x7e)))
		/* no obs-text */
	
}
