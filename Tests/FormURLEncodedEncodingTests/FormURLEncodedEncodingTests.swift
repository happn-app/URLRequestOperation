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
		XCTAssertEqual(try encoder.encode(value), "hello[]=119&hello[]=111&hello[]=114&hello[]=108&hello[]=100")
	}
	
	func testBasicDate() {
		let date = Date()
		let value = ["hello": date]
		let encoder = FormURLEncodedEncoder()
		XCTAssertEqual(try encoder.encode(value), "hello=\(date.timeIntervalSince1970)")
	}
	
}
