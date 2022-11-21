import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



public protocol ResultProcessor {
	
	associatedtype SourceType
	associatedtype ResultType

	@Sendable
	func transform(source: SourceType, urlResponse: URLResponse, handler: @Sendable @escaping (Result<ResultType, Error>) -> Void)
	
}
