import XCTest
@testable import URLRequestOperationTests
@testable import ReachabilityTests



XCTMain([
	testCase(URLRequestOperationTests.allTests),
	testCase(ReachabilityTests.allTests),
	testCase(IPUtilsTests.allTests)
])
