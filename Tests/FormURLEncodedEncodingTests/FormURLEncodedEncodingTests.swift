import Foundation
import XCTest

@testable import FormURLEncodedEncoding



class FormURLEncodedEncodingTests : XCTestCase {
	
	func testBasicEncode() {
		let value = ["hello": "world"]
		let encoder = FormURLEncodedEncoder()
		XCTAssertEqual(try encoder.encode(value), "hello=world")
	}
	
	func testBasicData() {
		let value = ["hello": Data("world".utf8)]
		let encoder = FormURLEncodedEncoder()
		XCTAssertEqual(try encoder.encode(value), "hello=world")
	}
	
	func testBasicDate() {
		let date = Date()
		let value = ["hello": date]
		let encoder = FormURLEncodedEncoder()
		XCTAssertEqual(try encoder.encode(value), "hello=\(date.timeIntervalSince1970)")
	}
	
}
