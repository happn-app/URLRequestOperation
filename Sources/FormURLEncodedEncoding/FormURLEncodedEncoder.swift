import Foundation



public class FormURLEncodedEncoder {
	
	public func encode<T : Encodable>(_ value: T) throws -> String {
		let encoding = FormURLEncodedEncoderImpl()
		try value.encode(to: encoding)
		return formURLEncodedFormat(from: encoding.data.values)
	}
	
	private func formURLEncodedFormat(from values: [String: Data]) -> String {
		let dotStrings = values.map{ "\($0)=\(String(data: $1, encoding: .utf8)!)" }
		return dotStrings.joined(separator: "&")
	}
	
}


fileprivate struct FormURLEncodedEncoderImpl : Encoder {
	
	fileprivate enum Value {
		case string(String)
		case date
	}
	
	fileprivate final class EncodingData {
		private(set) var values: [String: Data] = [:]
		
		func encode(key codingKey: [CodingKey], value: Data) {
			let key = codingKey.map{ $0.stringValue }.joined(separator: ".")
			values[key] = value
		}
	}
	
	fileprivate var data: EncodingData
	
	init(to encodedData: EncodingData = EncodingData()) {
		self.data = encodedData
	}
	
	var codingPath: [CodingKey] = []
	
	let userInfo: [CodingUserInfoKey : Any] = [:]
	
	func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
		var container = FormURLKeyedEncoding<Key>(to: data)
		container.codingPath = codingPath
		return KeyedEncodingContainer(container)
	}
	
	func unkeyedContainer() -> UnkeyedEncodingContainer {
		var container = FormURLUnkeyedEncoding(to: data)
		container.codingPath = codingPath
		return container
	}
	
	func singleValueContainer() -> SingleValueEncodingContainer {
		var container = FormURLSingleValueEncoding(to: data)
		container.codingPath = codingPath
		return container
	}
	
}


fileprivate struct FormURLKeyedEncoding<Key : CodingKey> : KeyedEncodingContainerProtocol {
	
	private let data: FormURLEncodedEncoderImpl.EncodingData
	
	init(to data: FormURLEncodedEncoderImpl.EncodingData) {
		self.data = data
	}
	
	var codingPath: [CodingKey] = []
	
	mutating func encodeNil(forKey key: Key) throws {
		/* Skip */
	}
	
	mutating func encode(_ value: Bool, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data((value ? "true" : "false").utf8))
	}
	
	mutating func encode(_ value: String, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(value.utf8))
	}
	
	mutating func encode(_ value: Double, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Float, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int8, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int16, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int32, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int64, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt8, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt16, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt32, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt64, forKey key: Key) throws {
		data.encode(key: codingPath + [key], value: Data(String(value).utf8))
	}
	
	mutating func encode<T : Encodable>(_ value: T, forKey key: Key) throws {
		var formURLEncodedEncoding = FormURLEncodedEncoderImpl(to: data)
		formURLEncodedEncoding.codingPath.append(key)
		try value.encode(to: formURLEncodedEncoding)
	}
	
	mutating func nestedContainer<NestedKey : CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
		var container = FormURLKeyedEncoding<NestedKey>(to: data)
		container.codingPath = codingPath + [key]
		return KeyedEncodingContainer(container)
	}
	
	mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
		var container = FormURLUnkeyedEncoding(to: data)
		container.codingPath = codingPath + [key]
		return container
	}
	
	mutating func superEncoder() -> Encoder {
		let superKey = Key(stringValue: "super")!
		return superEncoder(forKey: superKey)
	}
	
	mutating func superEncoder(forKey key: Key) -> Encoder {
		var formURLEncodedEncoding = FormURLEncodedEncoderImpl(to: data)
		formURLEncodedEncoding.codingPath = codingPath + [key]
		return formURLEncodedEncoding
	}
	
}


fileprivate struct FormURLUnkeyedEncoding : UnkeyedEncodingContainer {
	
	private let data: FormURLEncodedEncoderImpl.EncodingData
	
	init(to data: FormURLEncodedEncoderImpl.EncodingData) {
		self.data = data
	}
	
	var codingPath: [CodingKey] = []
	
	private(set) var count: Int = 0
	
	private mutating func nextIndexedKey() -> CodingKey {
		let nextCodingKey = IndexedCodingKey(intValue: count)!
		count += 1
		return nextCodingKey
	}
	
	private struct IndexedCodingKey : CodingKey {
		let intValue: Int?
		let stringValue: String
		
		init?(intValue: Int) {
			self.intValue = intValue
			self.stringValue = intValue.description
		}
		
		init?(stringValue: String) {
			return nil
		}
	}
	
	mutating func encodeNil() throws {
		/* Skip */
	}
	
	mutating func encode(_ value: Bool) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data((value ? "true" : "false").utf8))
	}
	
	mutating func encode(_ value: String) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(value.utf8))
	}
	
	mutating func encode(_ value: Double) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Float) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int8) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int16) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int32) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int64) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt8) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt16) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt32) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt64) throws {
		data.encode(key: codingPath + [nextIndexedKey()], value: Data(String(value).utf8))
	}
	
	mutating func encode<T : Encodable>(_ value: T) throws {
		var formURLEncodedEncoding = FormURLEncodedEncoderImpl(to: data)
		formURLEncodedEncoding.codingPath = codingPath + [nextIndexedKey()]
		try value.encode(to: formURLEncodedEncoding)
	}
	
	mutating func nestedContainer<NestedKey : CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
		var container = FormURLKeyedEncoding<NestedKey>(to: data)
		container.codingPath = codingPath + [nextIndexedKey()]
		return KeyedEncodingContainer(container)
	}
	
	mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
		var container = FormURLUnkeyedEncoding(to: data)
		container.codingPath = codingPath + [nextIndexedKey()]
		return container
	}
	
	mutating func superEncoder() -> Encoder {
		var formURLEncodedEncoding = FormURLEncodedEncoderImpl(to: data)
		formURLEncodedEncoding.codingPath.append(nextIndexedKey())
		return formURLEncodedEncoding
	}
	
}


fileprivate struct FormURLSingleValueEncoding: SingleValueEncodingContainer {
	
	private let data: FormURLEncodedEncoderImpl.EncodingData
	
	init(to data: FormURLEncodedEncoderImpl.EncodingData) {
		self.data = data
	}
	
	var codingPath: [CodingKey] = []
	
	mutating func encodeNil() throws {
		/* Skip */
	}
	
	mutating func encode(_ value: Bool) throws {
		data.encode(key: codingPath, value: Data((value ? "true" : "false").utf8))
	}
	
	mutating func encode(_ value: String) throws {
		data.encode(key: codingPath, value: Data(value.utf8))
	}
	
	mutating func encode(_ value: Double) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Float) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int8) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int16) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int32) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: Int64) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt8) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt16) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt32) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode(_ value: UInt64) throws {
		data.encode(key: codingPath, value: Data(String(value).utf8))
	}
	
	mutating func encode<T : Encodable>(_ value: T) throws {
		var formURLEncodedEncoding = FormURLEncodedEncoderImpl(to: data)
		formURLEncodedEncoding.codingPath = codingPath
		try value.encode(to: formURLEncodedEncoding)
	}
	
}
