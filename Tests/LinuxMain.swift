import XCTest
@testable import URLRequestOperationTests



XCTMain([
	testCase(URLRequestOperationTests.allTests),
	testCase(ReachabilityTests.allTests),
	testCase(IPUtilsTests.allTests)
])
