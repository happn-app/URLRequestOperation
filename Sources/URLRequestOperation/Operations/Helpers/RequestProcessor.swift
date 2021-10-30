import Foundation



public protocol RequestProcessor {
	
	func transform(urlRequest: URLRequest, handler: @escaping (Result<URLRequest, Error>) -> Void)
	
}


//#if compiler(>=5.5) && canImport(_Concurrency)
//protocol AsyncRequestProcessor {
//	
//	@available(macOS 12.0.0, *)
//	func transform(urlRequest: URLRequest) async throws -> URLRequest
//	
//}
//#endif