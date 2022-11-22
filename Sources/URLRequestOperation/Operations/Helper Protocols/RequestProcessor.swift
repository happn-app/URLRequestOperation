import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



public protocol RequestProcessor {
	
	func transform(urlRequest: URLRequest, handler: @escaping @Sendable (Result<URLRequest, Error>) -> Void)
	
}


//#if compiler(>=5.5) && canImport(_Concurrency)
//protocol AsyncRequestProcessor {
//	
//	@available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *)
//	func transform(urlRequest: URLRequest) async throws -> URLRequest
//	
//}
//#endif
