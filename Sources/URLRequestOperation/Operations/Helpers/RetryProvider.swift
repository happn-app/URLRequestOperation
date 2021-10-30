import Foundation

import RetryingOperation



public protocol RetryProvider {
	
	associatedtype ResultType
	
	func retryHelpers(for result: Result<ResultType, Error>) -> [RetryHelper]?
	
}


public extension RetryProvider {
	
	var erased: AnyRetryProvider<ResultType> {
		return .init(self)
	}
	
}


public struct AnyRetryProvider<ResultType> : RetryProvider {
	
	public init<RP : RetryProvider>(_ p: RP) where RP.ResultType == Self.ResultType {
		self.retryHelpersHandler = p.retryHelpers
	}
	
	public init(retryHelpersHandler: @escaping (Result<ResultType, Error>) -> [RetryHelper]?) {
		self.retryHelpersHandler = retryHelpersHandler
	}
	
	public init(errorRetryHelpersHandler: @escaping (Error?) -> [RetryHelper]?) {
		self.retryHelpersHandler = { r in errorRetryHelpersHandler(r.failure) }
	}
	
	public func retryHelpers(for result: Result<ResultType, Error>) -> [RetryHelper]? {
		return retryHelpersHandler(result)
	}
	
	private let retryHelpersHandler: (Result<ResultType, Error>) -> [RetryHelper]?
	
}
