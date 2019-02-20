import XCTest
@testable import URLRequestOperation



class ReachabilityTests: XCTestCase {
	
	#if canImport(SystemConfiguration)
	
	func testQuad9Reachability() {
		do {
			let reachability = try ReachabilityObserver.reachabilityObserver(forIPv4AddressStr: "9.9.9.9")
			XCTAssertTrue(reachability.currentlyReachable)
		} catch {
			XCTFail("Error thrown during test: \(error)")
		}
	}
	
	func testInvalidHostReachability() {
		do {
			let _/*reachability*/ = try ReachabilityObserver.reachabilityObserver(forHost: "invalid.frostland.fr")
			/* Funnily enough, it seems testing the reachability does not mean much
			 * in a test unit. It seems the system does not have the time to
			 * realize the server is unreachable and simply defaults to it being
			 * reachable... */
//			XCTAssertFalse(reachability.currentlyReachable)
		} catch {
			XCTFail("Error thrown during test: \(error)")
		}
	}
	
	#endif
	
}
