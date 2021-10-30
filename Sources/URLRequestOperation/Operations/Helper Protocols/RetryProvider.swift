import Foundation

import RetryingOperation



public protocol RetryProvider {
	
	associatedtype ResultType
	
	func retryHelpers(for request: URLRequest, result: Result<ResultType, Error>, operation: URLRequestOperation) -> [RetryHelper]?
	
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
	
	public init(retryHelpersHandler: @escaping (URLRequest, Result<ResultType, Error>, URLRequestOperation) -> [RetryHelper]?) {
		self.retryHelpersHandler = retryHelpersHandler
	}
	
	public init(errorRetryHelpersHandler: @escaping (URLRequest, Error?, URLRequestOperation) -> [RetryHelper]?) {
		self.retryHelpersHandler = { req, res, op in errorRetryHelpersHandler(req, res.failure, op) }
	}
	
	public func retryHelpers(for request: URLRequest, result: Result<ResultType, Error>, operation: URLRequestOperation) -> [RetryHelper]? {
		return retryHelpersHandler(request, result, operation)
	}
	
	private let retryHelpersHandler: (URLRequest, Result<ResultType, Error>, URLRequestOperation) -> [RetryHelper]?
	
}
