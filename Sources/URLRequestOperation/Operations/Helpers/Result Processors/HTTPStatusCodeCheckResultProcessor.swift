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



public struct HTTPStatusCodeCheckResultProcessor : ResultProcessor {
	
	public typealias SourceType = Data
	public typealias ResultType = Data
	
	public let expectedCodes: Set<Int>
	
	public init(expectedCodes: Set<Int> = Set(200..<400)) {
		self.expectedCodes = expectedCodes
	}
	
	public func transform(source: Data, urlResponse: URLResponse, handler: @escaping (Result<ResultType, Error>) -> Void) {
		handler(Result{
			guard let code = (urlResponse as? HTTPURLResponse)?.statusCode else {
				throw Err.unexpectedStatusCode(nil, httpBody: source)
			}
			guard expectedCodes.contains(code) else {
				throw Err.unexpectedStatusCode(code, httpBody: source)
			}
			return source
		})
	}
	
}
