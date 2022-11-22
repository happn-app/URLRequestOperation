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




public extension ResultProcessor {
	
	func map<NewResult>(_ transform: @escaping @Sendable (ResultType) -> NewResult) -> AnyResultProcessor<SourceType, NewResult> {
		return AnyResultProcessor<SourceType, NewResult>(transformingSuccessOf: self, with: transform)
	}
	
	func flatMap<NewProcessor : ResultProcessor>(_ newProcessor: NewProcessor) -> AnyResultProcessor<SourceType, NewProcessor.ResultType>
	where NewProcessor.SourceType == ResultType {
		return AnyResultProcessor<SourceType, NewProcessor.ResultType>(combining: self, and: newProcessor)
	}
	
	func flatMap<NewResult : Sendable>(_ flatMapHandler: @Sendable @escaping (ResultType, URLResponse) throws -> NewResult) -> AnyResultProcessor<SourceType, NewResult> {
		return flatMap(AnyResultProcessor<ResultType, NewResult>{ result, urlResponse, handler in handler(Result{ try flatMapHandler(result, urlResponse) }) })
	}
	
	func flatMapError<NewProcessor : ResultProcessor & Sendable>(_ newProcessor: NewProcessor) -> AnyResultProcessor<SourceType, ResultType>
	where NewProcessor.SourceType == Error, NewProcessor.ResultType == ResultType {
		return AnyResultProcessor<SourceType, ResultType>(recoveringErrorFrom: self, with: newProcessor)
	}
	
	func flatMapError(_ flatMapErrorHandler: @Sendable @escaping (Error, URLResponse) throws -> ResultType) -> AnyResultProcessor<SourceType, ResultType> {
		return flatMapError(AnyResultProcessor<Error, ResultType>{ error, urlResponse, handler in handler(Result{ try flatMapErrorHandler(error, urlResponse) }) })
	}
	
	func dispatched(to dispatcher: BlockDispatcher) -> AnyResultProcessor<SourceType, ResultType> {
		return AnyResultProcessor<SourceType, ResultType>(dispatching: self, to: dispatcher)
	}
	
	var erased: AnyResultProcessor<SourceType, ResultType> {
		return .init(self)
	}
	
}


public struct AnyResultProcessor<SourceType : Sendable, ResultType : Sendable> : ResultProcessor {

	public static func identity<T>() -> AnyResultProcessor<T, T> {
		return AnyResultProcessor<T, T>(transformHandler: { s, _, h in h(.success(s)) })
	}
	
	public init<RP : ResultProcessor & Sendable>(_ rp: RP) where RP.SourceType == Self.SourceType, RP.ResultType == Self.ResultType {
		self.transformHandler = rp.transform
	}
	
	public init<RP : ResultProcessor & Sendable>(dispatching rp: RP, to dispatcher: BlockDispatcher) where Self.SourceType : Sendable, RP.SourceType == Self.SourceType, RP.ResultType == Self.ResultType {
		self.transformHandler = { s, u, h in
			dispatcher.execute{
				rp.transform(source: s, urlResponse: u, handler: h)
			}
		}
	}
	
	public init<RP : ResultProcessor & Sendable>(transformingSuccessOf rp: RP, toErrorWith transform: @Sendable @escaping (RP.ResultType) -> Error)
	where RP.SourceType == Self.SourceType, RP.ResultType == Self.ResultType {
		self.transformHandler = { source, response, handler in
			rp.transform(source: source, urlResponse: response, handler: { result in
				handler(result.flatMap{ .failure(transform($0)) })
			})
		}
	}
	
	/* map */
	public init<RP : ResultProcessor & Sendable>(transformingSuccessOf rp: RP, with transform: @Sendable @escaping (RP.ResultType) -> ResultType)
	where RP.SourceType == Self.SourceType {
		self.transformHandler = { source, response, handler in
			rp.transform(source: source, urlResponse: response, handler: { result in
				handler(result.map(transform))
			})
		}
	}
	
	/* flatMap */
	public init<RP1 : ResultProcessor & Sendable, RP2 : ResultProcessor & Sendable>(combining rp1: RP1, and rp2: RP2)
	where RP1.SourceType == Self.SourceType, RP1.ResultType == RP2.SourceType, RP2.ResultType == Self.ResultType {
		self.transformHandler = { source, response, handler in
			rp1.transform(source: source, urlResponse: response, handler: { result in
				switch result {
					case .success(let v): rp2.transform(source: v, urlResponse: response, handler: handler)
					case .failure(let e): handler(.failure(e))
				}
			})
		}
	}
	
	/* flatMapError */
	public init<RP1 : ResultProcessor & Sendable, RP2 : ResultProcessor & Sendable>(recoveringErrorFrom rp1: RP1, with rp2: RP2)
	where RP1.SourceType == Self.SourceType, RP1.ResultType == Self.ResultType,
			RP2.SourceType == Error,           RP2.ResultType == Self.ResultType
	{
		self.transformHandler = { source, response, handler in
			rp1.transform(source: source, urlResponse: response, handler: { result in
				switch result {
					case .success: handler(result)
					case .failure(let e): rp2.transform(source: e, urlResponse: response, handler: handler)
				}
			})
		}
	}
	
	public init(transformHandler: @Sendable @escaping (SourceType, URLResponse, @Sendable @escaping (Result<ResultType, Error>) -> Void) -> Void) {
		self.transformHandler = transformHandler
	}
	
	public func transform(source: SourceType, urlResponse: URLResponse, handler: @Sendable @escaping (Result<ResultType, Error>) -> Void) {
		transformHandler(source, urlResponse, handler)
	}
	
	private let transformHandler: @Sendable (SourceType, URLResponse, @Sendable @escaping (Result<ResultType, Error>) -> Void) -> Void
	
}
