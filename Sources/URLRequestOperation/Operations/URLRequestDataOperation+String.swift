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



public extension URLRequestDataOperation {
	
	static func forString(
		urlRequest: URLRequest, session: URLSession = .shared,
		encoding: String.Encoding = URLRequestOperationConfig.defaultStringEncoding,
		requestProcessors: [RequestProcessor] = [],
		retryableStatusCodes: Set<Int> = URLRequestOperationConfig.defaultStringRetryableStatusCodes,
		retryProviders: [RetryProvider] = URLRequestOperationConfig.defaultStringRetryProviders
	) -> URLRequestDataOperation<ResultType> where ResultType == String {
		return URLRequestDataOperation<String>(
			request: urlRequest, session: session,
			requestProcessors: requestProcessors,
			urlResponseValidators: [HTTPStatusCodeURLResponseValidator()],
			resultProcessor: DecodeDataResultProcessor(decoder: { try dataToString($0, encoding: encoding) }).erased,
			retryProviders: [UnretriedErrorsRetryProvider.forWhitelistedStatusCodes(retryableStatusCodes)] + retryProviders
		)
	}
	
	static func forString(
		url: URL, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		encoding: String.Encoding = URLRequestOperationConfig.defaultStringEncoding,
		requestProcessors: [RequestProcessor] = [],
		retryableStatusCodes: Set<Int> = URLRequestOperationConfig.defaultStringRetryableStatusCodes,
		retryProviders: [RetryProvider] = URLRequestOperationConfig.defaultStringRetryProviders
	) -> URLRequestDataOperation<ResultType> where ResultType == String {
		var request = URLRequest(url: url, cachePolicy: cachePolicy)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		return Self.forString(
			urlRequest: request, session: session,
			encoding: encoding,
			requestProcessors: requestProcessors,
			retryableStatusCodes: retryableStatusCodes, retryProviders: retryProviders
		)
	}
	
	private static func dataToString(_ data: Data, encoding: String.Encoding) throws -> String {
		guard let str = String(data: data, encoding: .utf8) else {
			throw StringConversionError(data: data, expectedEncoding: encoding)
		}
		return str
	}
	
}


public struct StringConversionError : Error {
	
	public let data: Data
	public let expectedEncoding: String.Encoding
	
	public init(data: Data, expectedEncoding: String.Encoding) {
		self.data = data
		self.expectedEncoding = expectedEncoding
	}
	
}
