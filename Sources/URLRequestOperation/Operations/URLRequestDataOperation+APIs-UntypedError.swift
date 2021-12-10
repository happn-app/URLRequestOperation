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



public extension URLRequestDataOperation {
	
	/* Designated for APIs w/o an error type */
	static func forAPIRequest(
		urlRequest: URLRequest, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		let resultProcessor = HTTPStatusCodeCheckResultProcessor()
			.flatMap(DecodeHTTPContentResultProcessor<ResultType>(decoders: decoders, processingQueue: resultProcessingDispatcher))
		
		return URLRequestDataOperation<ResultType>(
			request: urlRequest, session: session, requestProcessors: requestProcessors,
			urlResponseValidators: [/* URL Response Validators do not make much sense for an API call */],
			resultProcessor: resultProcessor,
			retryProviders: [UnretriedErrorsRetryProvider.forStatusCodes(), UnretriedErrorsRetryProvider.forHTTPContentDecoding()] + retryProviders
		)
	}
	
	static func forAPIRequest(
		url: URL, method: String = "GET", headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		var request = URLRequest(url: url, cachePolicy: cachePolicy)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		request.httpMethod = method
		return Self.forAPIRequest(
			urlRequest: request, session: session,
			successType: successType,
			decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	/* Note: The `url` param should be named `baseURL` because the effective URL will be modified by the URL parameters.
	 *       However doing this is inconvenient it makes the method signature incompatible with other conveniences in this file. */
	static func forAPIRequest<URLParamtersType : Encodable>(
		url: URL, method: String = "GET", urlParameters: URLParamtersType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		return try Self.forAPIRequest(
			url: url, method: method, urlParameters: urlParameters, httpBody: nil as Int8?, headers: headers, cachePolicy: cachePolicy, session: session,
			successType: successType,
			parameterEncoder: parameterEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<HTTPBodyType : Encodable>(
		url: URL, method: String = "POST", httpBody: HTTPBodyType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self,
		bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		return try Self.forAPIRequest(
			url: url, method: method, urlParameters: nil as Int8?, httpBody: httpBody, headers: headers, cachePolicy: cachePolicy, session: session,
			successType: successType,
			bodyEncoder: bodyEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	/* Note: The `url` param should be named `baseURL` because the effective URL will be modified by the URL parameters.
	 *       However doing this is inconvenient it makes the method signature incompatible with other conveniences in this file. */
	static func forAPIRequest<URLParamtersType : Encodable, HTTPBodyType : Encodable>(
		url: URL, method: String = "POST", urlParameters: URLParamtersType?, httpBody: HTTPBodyType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self,
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
			successType: successType,
			decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
}
