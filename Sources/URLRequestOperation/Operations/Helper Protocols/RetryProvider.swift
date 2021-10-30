import Foundation

import RetryingOperation



public protocol RetryProvider {
	
	associatedtype ResultType
	
	func retryHelpers(for request: URLRequest, result: Result<ResultType, Error>) -> [RetryHelper]?
	
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
	
	public init(retryHelpersHandler: @escaping (URLRequest, Result<ResultType, Error>) -> [RetryHelper]?) {
		self.retryHelpersHandler = retryHelpersHandler
	}
	
	public init(errorRetryHelpersHandler: @escaping (URLRequest, Error?) -> [RetryHelper]?) {
		self.retryHelpersHandler = { req, res in errorRetryHelpersHandler(req, res.failure) }
	}
	
	public func retryHelpers(for request: URLRequest, result: Result<ResultType, Error>) -> [RetryHelper]? {
		return retryHelpersHandler(request, result)
	}
	
	private let retryHelpersHandler: (URLRequest, Result<ResultType, Error>) -> [RetryHelper]?
	
}
