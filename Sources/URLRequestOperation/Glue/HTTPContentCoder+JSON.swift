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

import MediaType



public func SendableJSONEncoderForHTTPContent(_ encoderConfig: @escaping @Sendable (JSONEncoder) -> Void = { _ in }) -> any HTTPContentEncoder {
	if #available(macOS 13.0, tvOS 16.0, iOS 16.0, watchOS 9.0, *) {let ret = JSONEncoder(); encoderConfig(ret); return ret}
	else                                                           {return SendableJSONEncoder(encoderConfig)}
}

@available(macOS 13.0, tvOS 16.0, iOS 16.0, watchOS 9.0, *)
extension JSONEncoder : HTTPContentEncoder {
	
	public func encodeForHTTPContent<T>(_ value: T) throws -> (Data, MediaType) where T : Encodable {
		return try (encode(value), MediaType(rawValue: "application/json")!)
	}
	
}
@available(iOS, deprecated: 16.0, message: "JSONEncoder is already Sendable on iOS 16, use it instead.")
@available(tvOS, deprecated: 16.0, message: "JSONEncoder is already Sendable on tvOS 16, use it instead.")
@available(macOS, deprecated: 13.0, message: "JSONEncoder is already Sendable on macOS 13, use it instead.")
@available(watchOS, deprecated: 9.0, message: "JSONEncoder is already Sendable on watchOS 9, use it instead.")
public struct SendableJSONEncoder : HTTPContentEncoder {
	public let encoderConfig: @Sendable (JSONEncoder) -> Void
	public init(_ encoderConfig: @escaping @Sendable (JSONEncoder) -> Void) {
		self.encoderConfig = encoderConfig
	}
	public func encodeForHTTPContent<T>(_ value: T) throws -> (Data, MediaType) where T : Encodable {
		let encoder = JSONEncoder()
		encoderConfig(encoder)
		return try (encoder.encode(value), MediaType(rawValue: "application/json")!)
	}
}


/* *******
   MARK: -
   ******* */

public func SendableJSONDecoderForHTTPContent(_ decoderConfig: @escaping @Sendable (JSONDecoder) -> Void = { _ in }) -> any HTTPContentDecoder {
	if #available(macOS 13.0, tvOS 16.0, iOS 16.0, watchOS 9.0, *) {let ret = JSONDecoder(); decoderConfig(ret); return ret}
	else                                                           {return SendableJSONDecoder(decoderConfig)}
}

@available(macOS 13.0, tvOS 16.0, iOS 16.0, watchOS 9.0, *)
extension JSONDecoder : HTTPContentDecoder {
	
	public func canDecodeHTTPContent(mediaType: MediaType) -> Bool {
		/* TODO: We assume UTF-8, but we should technically check. */
		return mediaType.subtype.split(separator: "+").last == "json"
	}
	
	public func decodeHTTPContent<T>(_ type: T.Type, from data: Data, mediaType: MediaType) throws -> T where T : Decodable {
		guard canDecodeHTTPContent(mediaType: mediaType) else {
			throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid media type \(mediaType)", underlyingError: nil))
		}
		return try decode(type, from: data)
	}
	
}
@available(iOS, deprecated: 16.0, message: "JSONDecoder is already Sendable on iOS 16, use it instead.")
@available(tvOS, deprecated: 16.0, message: "JSONDecoder is already Sendable on tvOS 16, use it instead.")
@available(macOS, deprecated: 13.0, message: "JSONDecoder is already Sendable on macOS 13, use it instead.")
@available(watchOS, deprecated: 9.0, message: "JSONDecoder is already Sendable on watchOS 9, use it instead.")
public struct SendableJSONDecoder : HTTPContentDecoder {
	public let decoderConfig: @Sendable (JSONDecoder) -> Void
	public init(_ decoderConfig: @escaping @Sendable (JSONDecoder) -> Void) {
		self.decoderConfig = decoderConfig
	}
	public func canDecodeHTTPContent(mediaType: MediaType) -> Bool {
		/* TODO: We assume UTF-8, but we should technically check. */
		return mediaType.subtype.split(separator: "+").last == "json"
	}
	public func decodeHTTPContent<T>(_ type: T.Type, from data: Data, mediaType: MediaType) throws -> T where T : Decodable {
		guard canDecodeHTTPContent(mediaType: mediaType) else {
			throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid media type \(mediaType)", underlyingError: nil))
		}
		let decoder = JSONDecoder()
		decoderConfig(decoder)
		return try decoder.decode(type, from: data)
	}
}
