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




public extension ResultProcessor {
	
	func map<NewResult>(_ transform: @escaping (ResultType) -> NewResult) -> AnyResultProcessor<SourceType, NewResult> {
		return AnyResultProcessor<SourceType, NewResult>(transformingSuccessOf: self, with: transform)
	}
	
	func flatMap<NewProcessor : ResultProcessor>(_ newProcessor: NewProcessor) -> AnyResultProcessor<SourceType, NewProcessor.ResultType>
	where NewProcessor.SourceType == ResultType {
		return AnyResultProcessor<SourceType, NewProcessor.ResultType>(combining: self, and: newProcessor)
	}
	
	func flatMapError<NewProcessor : ResultProcessor>(_ newProcessor: NewProcessor) -> AnyResultProcessor<SourceType, NewProcessor.ResultType>
	where NewProcessor.SourceType == Error, NewProcessor.ResultType == ResultType {
		return AnyResultProcessor<SourceType, NewProcessor.ResultType>(recoveringErrorFrom: self, with: newProcessor)
	}
	
	var erased: AnyResultProcessor<SourceType, ResultType> {
		return .init(self)
	}
	
}


public struct AnyResultProcessor<SourceType, ResultType> : ResultProcessor {
	
	public static func identity<T>() -> AnyResultProcessor<T, T> {
		return AnyResultProcessor<T, T>(transformHandler: { s, _, h in h(.success(s)) })
	}
	
	public init<RP : ResultProcessor>(_ p: RP) where RP.SourceType == Self.SourceType, RP.ResultType == Self.ResultType {
		self.transformHandler = p.transform
	}
	
	/* map */
	public init<RP : ResultProcessor>(transformingSuccessOf p1: RP, with transform: @escaping (RP.ResultType) -> ResultType)
	where RP.SourceType == Self.SourceType {
		self.transformHandler = { source, response, handler in
			p1.transform(source: source, urlResponse: response, handler: { result in
				handler(result.map(transform))
			})
		}
	}
	
	/* flatMap */
	public init<RP1 : ResultProcessor, RP2 : ResultProcessor>(combining p1: RP1, and p2: RP2)
	where RP1.SourceType == Self.SourceType, RP1.ResultType == RP2.SourceType, RP2.ResultType == Self.ResultType {
		self.transformHandler = { source, response, handler in
			p1.transform(source: source, urlResponse: response, handler: { result in
				switch result {
					case .success(let v): p2.transform(source: v, urlResponse: response, handler: handler)
					case .failure(let e): handler(.failure(e))
				}
			})
		}
	}
	
	/* flatMapError */
	public init<RP1 : ResultProcessor, RP2 : ResultProcessor>(recoveringErrorFrom p1: RP1, with p2: RP2)
	where RP1.SourceType == Self.SourceType, RP1.ResultType == Self.ResultType,
			RP2.SourceType == Error,           RP2.ResultType == Self.ResultType
	{
		self.transformHandler = { source, response, handler in
			p1.transform(source: source, urlResponse: response, handler: { result in
				switch result {
					case .success: handler(result)
					case .failure(let e): p2.transform(source: e, urlResponse: response, handler: handler)
				}
			})
		}
	}
	
	public init(transformHandler: @escaping (SourceType, URLResponse, @escaping (Result<ResultType, Error>) -> Void) -> Void) {
		self.transformHandler = transformHandler
	}
	
	public func transform(source: SourceType, urlResponse: URLResponse, handler: @escaping (Result<ResultType, Error>) -> Void) {
		transformHandler(source, urlResponse, handler)
	}
	
	private let transformHandler: (SourceType, URLResponse, @escaping (Result<ResultType, Error>) -> Void) -> Void
	
}
