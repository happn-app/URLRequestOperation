import Foundation
import XCTest

@testable import MediaType



class MediaTypeTests : XCTestCase {
	
	func testRFCExample() throws {
		let ex1 = try XCTUnwrap(MediaType(rawValue: #"text/html;charset=utf-8"#))
		let ex2 = try XCTUnwrap(MediaType(rawValue: #"text/html;charset=UTF-8"#))
		let ex3 = try XCTUnwrap(MediaType(rawValue: #"Text/HTML;Charset="utf-8""#))
		let ex4 = try XCTUnwrap(MediaType(rawValue: #"text/html; charset="utf-8""#))
		
		XCTAssertEqual(ex1, ex3)
		/* We do not compare ex1 and ex2 though doc says it should be equal, because we do not support parameter semantics. */
		XCTAssertEqual(ex1, ex4)
		XCTAssertEqual(ex3, ex4) /* If both previous one are true, this one better be true! */
		
		let normalized = "text/html;charset=utf-8"
		XCTAssertEqual(ex1.rawValue, normalized)
		XCTAssertEqual(ex2.rawValue, "text/html;charset=UTF-8") /* Same as above, we do not support parameter semantics. */
		XCTAssertEqual(ex3.rawValue, normalized)
		XCTAssertEqual(ex4.rawValue, normalized)
		
		XCTAssertEqual(ex1.type,    "text")
		XCTAssertEqual(ex1.subtype, "html")
	}
	
	func testQuotesInParameters() throws {
		let mediaType = try XCTUnwrap(MediaType(rawValue: #"unknown/bob;user="I am \"Bob\", you know?";name="\"Bob\"";age="42";sex=m"#))
		XCTAssertEqual(mediaType.rawValue, #"unknown/bob;user="I am \"Bob\", you know?";name="\"Bob\"";age=42;sex=m"#)
	}
	
}
