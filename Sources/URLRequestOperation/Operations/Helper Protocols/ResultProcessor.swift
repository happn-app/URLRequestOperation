import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



public protocol ResultProcessor {
	
	associatedtype SourceType
	associatedtype ResultType

	func transform(source: SourceType, urlResponse: URLResponse, handler: @escaping (Result<ResultType, Error>) -> Void)
	
}
