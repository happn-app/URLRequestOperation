/*
Copyright 2022 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



public protocol RequestProcessor : Sendable {
	
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
