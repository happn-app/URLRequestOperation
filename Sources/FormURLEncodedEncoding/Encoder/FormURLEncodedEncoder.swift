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



/**
 Encodes `Encodable` instances to `application/x-www-form-urlencoded` data.
 
 ```
 print(user) /* User */
 let data = try FormURLEncodedEncoder().encode(user)
 print(data) /* Data */
 ```
 
 URL-encoded forms are commonly used by websites to send form data via POST requests.
 This encoding is relatively efficient for small amounts of data but must be percent-encoded.
 `multipart/form-data` is more efficient for sending large data blobs like files.
 
 See [Mozilla's](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST) docs for more information about url-encoded forms.
 
 - Note: This implementation of the encoder does not support encoding booleans to "flags". */
public struct FormURLEncodedEncoder : Sendable {
	
	/** Used to capture URLForm Coding Configuration used for encoding. */
	public struct Configuration : Sendable {
		
		/** Supported array encodings. */
		public enum ArrayEncoding : Sendable {
			
			/**
			 Arrays are serialized as separate values with bracket suffixed keys.
			 
			 For example, `foo = [1,2,3]` would be serialized as `foo[]=1&foo[]=2&foo[]=3`. */
			case bracket
			/**
			 Arrays are serialized as a single value with character-separated items.
			 
			 For example, `foo = [1,2,3]` would be serialized as `foo=1,2,3`. */
			case separator(Character)
			/**
			 Arrays are serialized as separate values.
			 
			 For example, `foo = [1,2,3]` would be serialized as `foo=1&foo=2&foo=3`. */
			case values
			
		}
		
		/** Supported date formats */
		public enum DateEncodingStrategy : Sendable {
			
			/** Seconds since 1 January 1970 00:00:00 UTC (Unix Timestamp) */
			case secondsSince1970
			/** ISO 8601 formatted date */
			@available(macOS 10.12, *)
			case iso8601
			/** Using custom callback */
			case custom(@Sendable (Date, any Encoder) throws -> Void)
			
		}
		
		/** Specified array encoding. */
		public var arrayEncoding: ArrayEncoding
		public var dateEncodingStrategy: DateEncodingStrategy
		
		/**
		 Creates a new `Configuration`.
		 
		 - Parameter arrayEncoding: Specified array encoding. Defaults to `.bracket`.
		 - Parameter dateFormat: Format to encode date format too. Defaults to `secondsSince1970`. */
		public init(
			arrayEncoding: ArrayEncoding = .bracket,
			dateEncodingStrategy: DateEncodingStrategy = .secondsSince1970
		) {
			self.arrayEncoding = arrayEncoding
			self.dateEncodingStrategy = dateEncodingStrategy
		}
	}
	
	private let configuration: Configuration
	
	/**
	 Create a new `FormURLEncodedEncoder`.
	 
	 ```
	 ContentConfiguration.global.use(urlEncoder: FormURLEncodedEncoder(bracketsAsArray: true, flagsAsBool: true, arraySeparator: nil))
	 ```
	 
	 - parameters configuration: Defines how encoding is done see `URLEncodedFormCodingConfig` for more information */
	public init(
		configuration: Configuration = .init()
	) {
		self.configuration = configuration
	}
	
	/**
	 Encodes the supplied `Encodable` object to `Data`.
	 
	 ```
	 print(user) // User
	 let data = try FormURLEncodedEncoder().encode(user)
	 print(data) // "name=Vapor&age=3"
	 ```
	 
	 - Parameter encodable: Generic `Encodable` object (`E`) to encode.
	 - Parameter configuration: Overwrides the  coding config for this encoding call.
	 - Returns: Encoded `Data`
	 - Throws: Any error that may occur while attempting to encode the specified type. */
	public func encode<E>(_ encodable: E) throws -> String where E: Encodable {
		let encoder = _Encoder(codingPath: [], configuration: self.configuration)
		try encodable.encode(to: encoder)
		let serializer = FormURLEncodedSerializer()
		return try serializer.serialize(encoder.getData())
	}
	
}


/* *************
   MARK: Private
   ************* */

private protocol _Container {
	func getData() throws -> URLEncodedFormData
}

private class _Encoder: Encoder {
	
	var codingPath: [CodingKey]
	private var container: _Container? = nil
	
	func getData() throws -> URLEncodedFormData {
		return try container?.getData() ?? []
	}
	
	var userInfo: [CodingUserInfoKey: Any] {
		return [:]
	}
	
	private let configuration: FormURLEncodedEncoder.Configuration
	
	init(codingPath: [CodingKey], configuration: FormURLEncodedEncoder.Configuration) {
		self.codingPath = codingPath
		self.configuration = configuration
	}
	
	func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
		let container = KeyedContainer<Key>(codingPath: codingPath, configuration: configuration)
		self.container = container
		return .init(container)
	}
	
	func unkeyedContainer() -> UnkeyedEncodingContainer {
		let container = UnkeyedContainer(codingPath: codingPath, configuration: configuration)
		self.container = container
		return container
	}
	
	func singleValueContainer() -> SingleValueEncodingContainer {
		let container = SingleValueContainer(codingPath: codingPath, configuration: configuration)
		self.container = container
		return container
	}
	
	
	private final class KeyedContainer<Key>: KeyedEncodingContainerProtocol, _Container where Key: CodingKey {
		
		var codingPath: [CodingKey]
		var internalData: URLEncodedFormData = []
		var childContainers: [String: _Container] = [:]
		
		func getData() throws -> URLEncodedFormData {
			var result = internalData
			for (key, childContainer) in self.childContainers {
				result.children[key] = try childContainer.getData()
			}
			return result
		}
		
		private let configuration: FormURLEncodedEncoder.Configuration
		
		init(
			codingPath: [CodingKey],
			configuration: FormURLEncodedEncoder.Configuration
		) {
			self.codingPath = codingPath
			self.configuration = configuration
		}
		
		/** See `KeyedEncodingContainerProtocol` */
		func encodeNil(forKey key: Key) throws {
			/* skip */
		}
		
		/** See `KeyedEncodingContainerProtocol` */
		func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
			if let date = value as? Date {
				self.internalData.children[key.stringValue] = try configuration.encodeDate(date, codingPath: self.codingPath, forKey: key)
			} else if let convertible = value as? URLQueryFragmentConvertible {
				internalData.children[key.stringValue] = URLEncodedFormData(values: [convertible.urlQueryFragmentValue])
			} else {
				let encoder = _Encoder(codingPath: self.codingPath + [key], configuration: self.configuration)
				try value.encode(to: encoder)
				self.internalData.children[key.stringValue] = try encoder.getData()
			}
		}
		
		/** See `KeyedEncodingContainerProtocol` */
		func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
			let container = KeyedContainer<NestedKey>(
				codingPath: self.codingPath + [key],
				configuration: self.configuration
			)
			self.childContainers[key.stringValue] = container
			return .init(container)
		}
		
		/** See `KeyedEncodingContainerProtocol` */
		func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
			let container = UnkeyedContainer(
				codingPath: self.codingPath + [key],
				configuration: self.configuration
			)
			self.childContainers[key.stringValue] = container
			return container
		}
		
		/** See `KeyedEncodingContainerProtocol` */
		func superEncoder() -> Encoder {
			fatalError()
		}
		
		/** See `KeyedEncodingContainerProtocol` */
		func superEncoder(forKey key: Key) -> Encoder {
			fatalError()
		}
		
	}
	
	
	/** Private `UnkeyedEncodingContainer`. */
	private final class UnkeyedContainer: UnkeyedEncodingContainer, _Container {
		
		var codingPath: [CodingKey]
		var count: Int = 0
		var internalData: URLEncodedFormData = []
		var childContainers: [Int: _Container] = [:]
		private let configuration: FormURLEncodedEncoder.Configuration
		
		func getData() throws -> URLEncodedFormData {
			var result = self.internalData
			for (key, childContainer) in self.childContainers {
				result.children[String(key)] = try childContainer.getData()
			}
			switch self.configuration.arrayEncoding {
				case .separator(let arraySeparator):
					var valuesToImplode = result.values
					result.values = []
					if
						case .bracket = self.configuration.arrayEncoding,
						let emptyStringChild = self.internalData.children[""]
					{
						valuesToImplode = valuesToImplode + emptyStringChild.values
						result.children[""]?.values = []
					}
					let implodedValue = try valuesToImplode.map({ (value: URLQueryFragment) -> String in
						return try value.asUrlEncoded()
					}).joined(separator: String(arraySeparator))
					result.values = [.urlEncoded(implodedValue)]
				case .bracket, .values:
					break
			}
			return result
		}
		
		init(
			codingPath: [CodingKey],
			configuration: FormURLEncodedEncoder.Configuration
		) {
			self.codingPath = codingPath
			self.configuration = configuration
		}
		
		func encodeNil() throws {
			/* skip */
		}
		
		func encode<T>(_ value: T) throws where T: Encodable {
			defer {self.count += 1}
			if let convertible = value as? URLQueryFragmentConvertible {
				let value = convertible.urlQueryFragmentValue
				switch self.configuration.arrayEncoding {
					case .bracket:
						var emptyStringChild = self.internalData.children[""] ?? []
						emptyStringChild.values.append(value)
						self.internalData.children[""] = emptyStringChild
					case .separator, .values:
						self.internalData.values.append(value)
				}
			} else {
				let encoder = _Encoder(codingPath: codingPath, configuration: configuration)
				try value.encode(to: encoder)
				let childData = try encoder.getData()
				if childData.hasOnlyValues {
					switch self.configuration.arrayEncoding {
						case .bracket:
							var emptyStringChild = self.internalData.children[""] ?? []
							emptyStringChild.values.append(contentsOf: childData.values)
							self.internalData.children[""] = emptyStringChild
						case .separator, .values:
							self.internalData.values.append(contentsOf: childData.values)
					}
				} else {
					self.internalData.children[count.description] = try encoder.getData()
				}
			}
		}
		
		/** See UnkeyedEncodingContainer.nestedContainer */
		func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
			defer { count += 1 }
			let container = KeyedContainer<NestedKey>(
				codingPath: self.codingPath,
				configuration: self.configuration
			)
			self.childContainers[self.count] = container
			return .init(container)
		}
		
		/** See UnkeyedEncodingContainer.nestedContainer */
		func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
			defer { count += 1 }
			let container = UnkeyedContainer(
				codingPath: self.codingPath,
				configuration: self.configuration
			)
			self.childContainers[count] = container
			return container
		}
		
		/** See UnkeyedEncodingContainer.nestedContainer */
		func superEncoder() -> Encoder {
			fatalError()
		}
		
	}
	
	
	/** Private `SingleValueEncodingContainer`. */
	private final class SingleValueContainer: SingleValueEncodingContainer, _Container {
		
		/** See `SingleValueEncodingContainer` */
		var codingPath: [CodingKey]
		
		func getData() throws -> URLEncodedFormData {
			return data
		}
		
		/** The data being encoded */
		var data: URLEncodedFormData = []
		
		private let configuration: FormURLEncodedEncoder.Configuration
		
		/** Creates a new single value encoder */
		init(
			codingPath: [CodingKey],
			configuration: FormURLEncodedEncoder.Configuration
		) {
			self.codingPath = codingPath
			self.configuration = configuration
		}
		
		/** See `SingleValueEncodingContainer` */
		func encodeNil() throws {
			/* skip */
		}
		
		/** See `SingleValueEncodingContainer` */
		func encode<T>(_ value: T) throws where T: Encodable {
			if let date = value as? Date {
				self.data = try configuration.encodeDate(date, codingPath: self.codingPath, forKey: nil)
			} else if let convertible = value as? URLQueryFragmentConvertible {
				self.data.values.append(convertible.urlQueryFragmentValue)
			} else {
				let encoder = _Encoder(codingPath: self.codingPath, configuration: self.configuration)
				try value.encode(to: encoder)
				self.data = try encoder.getData()
			}
		}
		
	}
	
}


private extension FormURLEncodedEncoder.Configuration {
	
	func encodeDate(_ date: Date, codingPath: [CodingKey], forKey key: CodingKey?) throws -> URLEncodedFormData {
		switch dateEncodingStrategy {
			case .secondsSince1970:
				return URLEncodedFormData(values: [date.urlQueryFragmentValue])
			case .iso8601:
				guard #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) else {
					throw Err.iso8601DateFormatterUnavailable
				}
				return URLEncodedFormData(values: [
					/* Note: Vapor’s implementation uses a thread-specific to have a different formatter per thread and avoid re-allocating the formatter each time. */
					ISO8601DateFormatter().string(from: date).urlQueryFragmentValue
				])
			case .custom(let callback):
				let newCodingPath = codingPath + (key.map { [$0] } ?? [])
				let encoder = _Encoder(codingPath: newCodingPath, configuration: self)
				try callback(date, encoder)
				return try encoder.getData()
		}
	}
	
}


private extension EncodingError {
	
	static func invalidValue(_ value: Any, at path: [CodingKey]) -> EncodingError {
		let pathString = path.map { $0.stringValue }.joined(separator: ".")
		let context = EncodingError.Context(
			codingPath: path,
			debugDescription: "Invalid value at '\(pathString)': \(value)"
		)
		return Swift.EncodingError.invalidValue(value, context)
	}
	
}
