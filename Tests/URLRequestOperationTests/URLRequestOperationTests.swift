import XCTest
@testable import URLRequestOperation



class URLRequestOperationTests: XCTestCase {
	
	func testFetchFrostLandConstant() {
		let op = URLRequestOperation(url: URL(string: "https://frostland.fr/constant.txt")!)
		op.start()
		op.waitUntilFinished()
		XCTAssertNil(op.finalError)
		XCTAssertEqual(op.statusCode, 200)
		XCTAssertEqual(op.fetchedData, Data("42".utf8))
	}
	
	func testFetchInvalidHost() {
		let op = URLRequestOperation(config: URLRequestOperation.Config(request: URLRequest(url: URL(string: "https://invalid.frostland.fr/")!), session: nil, maximumNumberOfRetries: 1))
		op.start()
		op.waitUntilFinished()
		XCTAssertNotNil(op.finalError)
		XCTAssertNil(op.statusCode)
	}
	
	func testFetch404() {
		let op = URLRequestOperation(url: URL(string: "https://frostland.fr/this_page_does_not_exist.html")!)
		op.start()
		op.waitUntilFinished()
		XCTAssertNotNil(op.finalError)
		XCTAssertEqual(op.statusCode, 404)
	}
	
	
	/* Fill this array with all the tests to have Linux testing compatibility. */
	static var allTests = [
		("testFetchFrostLandConstant", testFetchFrostLandConstant),
		("testFetchInvalidHost", testFetchInvalidHost),
		("testFetch404", testFetch404)
	]
	
}
