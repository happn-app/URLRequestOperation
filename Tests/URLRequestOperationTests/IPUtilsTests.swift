import XCTest
@testable import URLRequestOperation



class IPUtilsTests: XCTestCase {
	
	func testSockaddrToString() {
		let ipstr = "9.9.9.9"
		var sa = sockaddr_in()
		sa.sin_family = sa_family_t(AF_INET)
		sa.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
		XCTAssertEqual(inet_pton(AF_INET, ipstr, &sa.sin_addr), 1)
		
		XCTAssertEqual(try SockAddrWrapper(sockaddr_in: &sa).sockaddrStringRepresentation(), ipstr)
	}
	
	
	/* Fill this array with all the tests to have Linux testing compatibility. */
	static var allTests = [
		("testSockaddrToString", testSockaddrToString)
	]
	
}
