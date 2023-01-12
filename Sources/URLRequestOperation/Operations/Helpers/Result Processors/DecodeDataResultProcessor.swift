/*
Copyright 2021 happn

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



/** Throws ``URLRequestOperationError/DataConversionFailed`` errors. */
public struct DecodeDataResultProcessor<ResultType : Sendable> : ResultProcessor, Sendable {
	
	public typealias SourceType = Data
	
	public let decoder: @Sendable (Data) throws -> ResultType
	
	public let processingQueue: BlockDispatcher
	
	public init(jsonDecoder: JSONDecoder, processingQueue: BlockDispatcher = SyncBlockDispatcher()) where ResultType : Decodable {
		self.decoder = { try jsonDecoder.decode(ResultType.self, from: $0) }
		self.processingQueue = processingQueue
	}
	
	public init(decoder: @escaping @Sendable (Data) throws -> ResultType, processingQueue: BlockDispatcher = SyncBlockDispatcher()) {
		self.decoder = decoder
		self.processingQueue = processingQueue
	}
	
	public func transform(source: Data, urlResponse: URLResponse, handler: @Sendable @escaping (Result<ResultType, Error>) -> Void) {
		processingQueue.execute{ handler(Result{ try decoder(source) }.mapError{ DataConversionFailed(data: source, underlyingError: $0) }) }
	}
	
}
