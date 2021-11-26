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
	
	public init(transformHandler: @escaping (SourceType, URLResponse, @escaping (Result<ResultType, Error>) -> Void) -> Void) {
		self.transformHandler = transformHandler
	}
	
	public func transform(source: SourceType, urlResponse: URLResponse, handler: @escaping (Result<ResultType, Error>) -> Void) {
		transformHandler(source, urlResponse, handler)
	}
	
	private let transformHandler: (SourceType, URLResponse, @escaping (Result<ResultType, Error>) -> Void) -> Void
	
}
