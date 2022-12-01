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

#if compiler(>=5.5) && canImport(_Concurrency)

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



@available(macOS 10.15, tvOS 13.0, iOS 13.0, watchOS 6.0, *)
public struct AsyncBlockRequestProcessor : RequestProcessor {
	
	public let block: @Sendable (URLRequest) async throws -> URLRequest
	
	public init(_ block: @escaping @Sendable (URLRequest) async throws -> URLRequest) {
		self.block = block
	}
	
	public func transform(urlRequest: URLRequest, handler: @escaping @Sendable (Result<URLRequest, Error>) -> Void) {
		Task{
			do    {try await handler(.success(block(urlRequest)))}
			catch {          handler(.failure(error))}
		}
	}
	
}

#endif
