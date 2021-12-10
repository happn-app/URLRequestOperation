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

import FormURLEncodedEncoding



/* Initially, in these convenient methods, instead of passing the URL directly, there was a base URL and a path component.
 * Now you have to pass the full URL directly (except for query params which can be passed in these convenient methods),
 * but a convenience _on URL_ has been added in URLRequestOperation: `appendingPathComponentsSafely(_:)`.
 * This convenience allows adding path components while checking all path components are valid (they do not contain a forward slash).
 *
 *
 * Original thoughts on the subject (before moving to separate convenience):
 *
 * In all of these convenient methods, I’d have liked to have an array of path components instead of a path to add to the base URL.
 * A great advantage of doing this is we can check each component to be a valid path component (does not contain a forward slash) and fail if one is not.
 * Ideally, I’d want the path components to be defined as a variadic string, so we can do this:
 *    try URLRequestDataOperation.forAPIRequest(baseURL: amazingURL, path: "api", "v1", "user", userID)
 * for instance.
 * However this poses multiple issues:
 *    - First variadic arguments cannot be forwarded to another function in Swift (a proposal was submitted https://forums.swift.org/t/26718 but never landed).
 *      In itself this is an implementation issue only. We’d simply have to declare the array version and the variadic version, and we’d be good.
 *      In practice this is annoying.
 *    - The methods all become throwing! Because indeed, if one of the path component is invalid, we have to reject that input.
 *      If the path is not set, I’d like the method to be non-throwing, of course.
 *      Which means one more overload variant to do… */

public extension URLRequestDataOperation {
	
	/* Designated for APIs w/ an error type */
	static func forAPIRequest<APIErrorType : Decodable>(
		urlRequest: URLRequest, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		let resultProcessor = HTTPStatusCodeCheckResultProcessor()
			.flatMap(DecodeHTTPContentResultProcessor<ResultType>(decoders: decoders, processingQueue: resultProcessingDispatcher))
			.flatMapError(
				RecoverHTTPStatusCodeCheckErrorResultProcessor()
					.flatMap(DecodeHTTPContentResultProcessor<APIErrorType>(decoders: decoders, processingQueue: resultProcessingDispatcher))
					.flatMap{ Result<ResultType, Error>.failure(Err.APIResultErrorWrapper(urlResponse: $1, error: $0)) }
			)
		
		return URLRequestDataOperation<ResultType>(
			request: urlRequest, session: session, requestProcessors: requestProcessors,
			urlResponseValidators: [/* URL Response Validators do not make much sense for an API call */],
			resultProcessor: resultProcessor,
			retryProviders: [UnretriedErrorsRetryProvider.forAPIError(errorType: APIErrorType.self), UnretriedErrorsRetryProvider.forHTTPContentDecoding()] + retryProviders
		)
	}
	
	static func forAPIRequest<APIErrorType : Decodable>(
		url: URL, method: String = "GET", headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		var request = URLRequest(url: url, cachePolicy: cachePolicy)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		request.httpMethod = method
		return Self.forAPIRequest(
			urlRequest: request, session: session,
			successType: successType, errorType: errorType,
			decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	/* Note: The `url` param should be named `baseURL` because the effective URL will be modified by the URL parameters.
	 *       However doing this is inconvenient it makes the method signature incompatible with other conveniences in this file. */
	static func forAPIRequest<APIErrorType : Decodable, URLParamtersType : Encodable>(
		url: URL, method: String = "GET", urlParameters: URLParamtersType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		return try Self.forAPIRequest(
			url: url, method: method, urlParameters: urlParameters, httpBody: nil as Int8?, headers: headers, cachePolicy: cachePolicy, session: session,
			successType: successType, errorType: errorType,
			parameterEncoder: parameterEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APIErrorType : Decodable, HTTPBodyType : Encodable>(
		url: URL, method: String = "POST", httpBody: HTTPBodyType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		return try Self.forAPIRequest(
			url: url, method: method, urlParameters: nil as Int8?, httpBody: httpBody, headers: headers, cachePolicy: cachePolicy, session: session,
			successType: successType, errorType: errorType,
			bodyEncoder: bodyEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	/* Note: The `url` param should be named `baseURL` because the effective URL will be modified by the URL parameters.
	 *       However doing this is inconvenient it makes the method signature incompatible with other conveniences in this file. */
	static func forAPIRequest<APIErrorType : Decodable, URLParamtersType : Encodable, HTTPBodyType : Encodable>(
		url: URL, method: String = "POST", urlParameters: URLParamtersType?, httpBody: HTTPBodyType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		let url = try url.addingQueryParameters(from: urlParameters, encoder: parameterEncoder)
		var request = URLRequest(url: url, cachePolicy: cachePolicy)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		request.httpMethod = method
		if let httpBody = httpBody {
			let (data, contentType) = try bodyEncoder.encodeForHTTPContent(httpBody)
			request.setValue(contentType.rawValue, forHTTPHeaderField: "content-type")
			request.httpBody = data
		}
		return Self.forAPIRequest(
			urlRequest: request, session: session,
			successType: successType, errorType: errorType,
			decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
}
