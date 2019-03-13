import XCTest

extension IPUtilsTests {
    static let __allTests = [
        ("testSockaddrToString", testSockaddrToString),
    ]
}

extension ReachabilityTests {
    static let __allTests = [
        ("testInvalidHostReachability", testInvalidHostReachability),
        ("testQuad9Reachability", testQuad9Reachability),
    ]
}

extension URLRequestOperationTests {
    static let __allTests = [
        ("testFetch404", testFetch404),
        ("testFetchFrostLandConstant", testFetchFrostLandConstant),
        ("testFetchInvalidHost", testFetchInvalidHost),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(IPUtilsTests.__allTests),
        testCase(ReachabilityTests.__allTests),
        testCase(URLRequestOperationTests.__allTests),
    ]
}
#endif
