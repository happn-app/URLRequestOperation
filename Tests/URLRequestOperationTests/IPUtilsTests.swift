/*
Copyright 2019 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import XCTest
@testable import URLRequestOperation



class IPUtilsTests: XCTestCase {
	
	func testSockaddrToString() {
		let ipstr = "9.9.9.9"
		var sa = sockaddr_in()
		sa.sin_family = sa_family_t(AF_INET)
#if !os(Linux)
		sa.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
#endif
		XCTAssertEqual(inet_pton(AF_INET, ipstr, &sa.sin_addr), 1)
		
		XCTAssertEqual(try SockAddrWrapper(sockaddr_in: &sa).sockaddrStringRepresentation(), ipstr)
	}
	
}
