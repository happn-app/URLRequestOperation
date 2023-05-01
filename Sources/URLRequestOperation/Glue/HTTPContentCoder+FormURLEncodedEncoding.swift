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

import FormURLEncodedCoder
import MediaType



extension FormURLEncodedEncoder : HTTPContentEncoder {
	
	public func encodeForHTTPContent<T>(_ value: T) throws -> (Data, MediaType) where T : Encodable {
		let encodedString: String = try encode(value)
		/* MediaType for form url encoded does not have a charset; content is expected to be UTF-8.
		 * https://stackoverflow.com/a/16829056 */
		return (Data(encodedString.utf8), MediaType(rawValue: "application/x-www-form-urlencoded")!)
	}
	
}


/* Mostly useless, but we keep for symmetry */
extension FormURLEncodedDecoder : HTTPContentDecoder {
	
	public func canDecodeHTTPContent(mediaType: MediaType) -> Bool {
		/* We compare only the part of the subtype after the last “+”:
		 *  it seems to be a common practice to define subtypes as “SUB_FORMAT+FORMAT” (e.g. “vnd.api+json”, “svg+xml”),
		 *  so we consider this being a norm and we parse the subtype.
		 * I have not found a standard confirming or infirming this though.
		 * For the same reason, we do NOT compare the type of the media-type (“application” in “application/json”):
		 *  for the “xml” example, we have “application/xml” and also “image/svg+xml” that we could theorically parse… */
		/* TODO: We assume UTF-8, but we should technically check. */
		return mediaType.subtype.split(separator: "+").last == "x-www-form-urlencoded"
	}
	
	public func decodeHTTPContent<T>(_ type: T.Type, from data: Data, mediaType: MediaType) throws -> T where T : Decodable {
		guard canDecodeHTTPContent(mediaType: mediaType) else {
			throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid media type \(mediaType)", underlyingError: nil))
		}
		guard let string = String(data: data, encoding: .utf8) else {
			throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Data is not valid utf8", underlyingError: nil))
		}
		return try decode(type, from: string)
	}
	
}
