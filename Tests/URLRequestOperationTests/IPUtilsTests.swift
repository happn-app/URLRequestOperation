import XCTest
@testable import URLRequestOperation



class IPUtilsTests: XCTestCase {
	
	func testSockaddrToString() {
		do {
			let ipstr = "9.9.9.9"
			var sa = sockaddr_in()
			sa.sin_family = sa_family_t(AF_INET)
			sa.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
			let successValue = inet_pton(AF_INET, ipstr, &sa.sin_addr)
			try processInetPToN(returnValue: successValue)
			XCTAssertEqual(try unsafeBitCast(sa, to: sockaddr.self).toString(), ipstr)
		} catch {
			XCTFail("Error thrown during test: \(error)")
		}
	}
	
	
	/* Fill this array with all the tests to have Linux testing compatibility. */
	static var allTests = [
		("testSockaddrToString", testSockaddrToString)
	]
	
}
