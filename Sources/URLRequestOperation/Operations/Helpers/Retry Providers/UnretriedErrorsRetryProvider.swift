import Foundation

import RetryingOperation



public struct UnretriedErrorsRetryProvider : RetryProvider {
	
	public let isBlacklistedError: (Error) -> Bool
	
	public init(isBlacklistedError: @escaping (Error) -> Bool) {
		self.isBlacklistedError = isBlacklistedError
	}
	
	public func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?? {
		if isBlacklistedError(error) {
			return .some(nil)
		}
		return nil
	}
	
}
