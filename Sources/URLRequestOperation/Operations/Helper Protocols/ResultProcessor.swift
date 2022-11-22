import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



public protocol ResultProcessor : Sendable {
	
	associatedtype SourceType : Sendable
	associatedtype ResultType : Sendable

	@Sendable
	func transform(source: SourceType, urlResponse: URLResponse, handler: @escaping @Sendable (Result<ResultType, Error>) -> Void)
	
}
