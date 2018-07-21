import XCTest
@testable import URLRequestOperationTests
@testable import ReachabilityTests



XCTMain([
	testCase(URLRequestOperationTests.allTests),
#if canImport(SystemConfiguration)
	testCase(ReachabilityTests.allTests),
#endif
	testCase(IPUtilsTests.allTests)
])
