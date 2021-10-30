import Foundation

import RetryingOperation



public protocol RetryProvider {
	
	associatedtype ResultType
	
	func canRetry(with result: Result<ResultType, Error>) -> Bool
	func retryHelpers(for result: Result<ResultType, Error>) -> [RetryHelper]?
	
}


public extension RetryProvider {
	
	var erased: AnyRetryProvider<ResultType> {
		return .init(self)
	}
	
}


public struct AnyRetryProvider<ResultType> : RetryProvider {
	
	public init<RP : RetryProvider>(_ p: RP) where RP.ResultType == Self.ResultType {
		self.canRetryHandler = p.canRetry
		self.retryHelpersHandler = p.retryHelpers
	}
	
	public init(retryHelpersHandler: @escaping (Result<ResultType, Error>) -> [RetryHelper]?, canRetryHandler: @escaping (Result<ResultType, Error>) -> Bool) {
		self.canRetryHandler = canRetryHandler
		self.retryHelpersHandler = retryHelpersHandler
	}
	
	public init(errorRetryHelpersHandler: @escaping (Error?) -> [RetryHelper]?, errorCanRetryHandler: @escaping (Error?) -> Bool) {
		self.canRetryHandler = { r in errorCanRetryHandler(r.failure) }
		self.retryHelpersHandler = { r in errorRetryHelpersHandler(r.failure) }
	}
	
	public func canRetry(with result: Result<ResultType, Error>) -> Bool {
		return canRetryHandler(result)
	}
	
	public func retryHelpers(for result: Result<ResultType, Error>) -> [RetryHelper]? {
		return retryHelpersHandler(result)
	}
	
	private let canRetryHandler: (Result<ResultType, Error>) -> Bool
	private let retryHelpersHandler: (Result<ResultType, Error>) -> [RetryHelper]?
	
}
