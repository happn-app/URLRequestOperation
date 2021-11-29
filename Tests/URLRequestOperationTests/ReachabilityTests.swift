/*
Copyright 2019-2021 happn

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



class ReachabilityTests : XCTestCase {
	
#if canImport(SystemConfiguration)
	
	func testQuad9Reachability() {
		do {
			let reachability = try ReachabilityObserver.reachabilityObserver(forIPv4AddressStr: "9.9.9.9")
			XCTAssertTrue(reachability.currentlyReachable ?? false)
		} catch {
			XCTFail("Error thrown during test: \(error)")
		}
	}
	
	func testInvalidHostReachability() {
		do {
			let _/*reachability*/ = try ReachabilityObserver.reachabilityObserver(forHost: "invalid.frostland.fr")
			/* Funnily enough, it seems testing the reachability does not mean much in a test unit.
			 * It seems the system does not have the time to realize the server is unreachable
			 * and simply defaults to it being reachable… */
//			XCTAssertFalse(reachability.currentlyReachable)
		} catch {
			XCTFail("Error thrown during test: \(error)")
		}
	}
	
#endif
	
}
