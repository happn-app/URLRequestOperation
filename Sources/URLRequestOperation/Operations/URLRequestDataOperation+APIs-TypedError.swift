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
	
	/* Designated for APIs w/ an error type */
	static func forAPIRequest<APIErrorType : Decodable>(
		urlRequest: URLRequest, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		/* TODO: Is this the best dispatch? */
		let resultProcessor = HTTPStatusCodeCheckResultProcessor()
			.flatMap(DecodeHTTPContentResultProcessor<ResultType>(decoders: decoders, processingQueue: SyncBlockDispatcher()))
			.flatMapError(
				RecoverHTTPStatusCodeCheckErrorResultProcessor()
					.flatMap(DecodeHTTPContentResultProcessor<APIErrorType>(decoders: decoders, processingQueue: SyncBlockDispatcher()))
					.flatMap{ Result<ResultType, Error>.failure(Err.APIResultErrorWrapper(urlResponse: $1, error: $0)) }
			)
			.dispatched(to: resultProcessingDispatcher)
		
		return URLRequestDataOperation<ResultType>(
			request: urlRequest, session: session, requestProcessors: requestProcessors,
			urlResponseValidators: [/* URL Response Validators do not make much sense for an API call */],
			resultProcessor: resultProcessor,
			retryProviders: [UnretriedErrorsRetryProvider.forAPIError(errorType: APIErrorType.self), UnretriedErrorsRetryProvider.forHTTPContentDecoding()] + retryProviders
		)
	}
	
	static func forAPIRequest<APIErrorType : Decodable>(
		baseURL: URL, path: String, method: String = "GET", headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		let url = baseURL.appendingPathComponent(path)
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
	
	static func forAPIRequest<APIErrorType : Decodable, URLParamtersType : Encodable>(
		baseURL: URL, path: String, method: String = "GET", urlParameters: URLParamtersType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		return try Self.forAPIRequest(
			baseURL: baseURL, path: path, method: method, urlParameters: urlParameters, httpBody: nil as Int8?, headers: headers, cachePolicy: cachePolicy, session: session,
			successType: successType, errorType: errorType,
			parameterEncoder: parameterEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APIErrorType : Decodable, HTTPBodyType : Encodable>(
		baseURL: URL, path: String, method: String = "POST", httpBody: HTTPBodyType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		return try Self.forAPIRequest(
			baseURL: baseURL, path: path, method: method, urlParameters: nil as Int8?, httpBody: httpBody, headers: headers, cachePolicy: cachePolicy, session: session,
			successType: successType, errorType: errorType,
			bodyEncoder: bodyEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APIErrorType : Decodable, URLParamtersType : Encodable, HTTPBodyType : Encodable>(
		baseURL: URL, path: String, method: String = "POST", urlParameters: URLParamtersType?, httpBody: HTTPBodyType?, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		successType: ResultType.Type = ResultType.self, errorType: APIErrorType.Type = APIErrorType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType : Decodable {
		let url = baseURL.appendingPathComponent(path)
		var request = try URLRequest(
			url: urlParameters.flatMap{ try url.addingQueryParameters(from: $0, encoder: parameterEncoder) } ?? url,
			cachePolicy: cachePolicy
		)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		request.httpMethod = method
		if let httpBody = httpBody {
			let (data, contentType) = try bodyEncoder.encode(httpBody)
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
