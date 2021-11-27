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
	
	/* Designated for APIs */
	static func forAPIRequest<APISuccessType : Decodable, APIErrorType : Decodable>(
		urlRequest: URLRequest, session: URLSession = .shared,
		successType: APISuccessType.Type = APISuccessType.self, errorType: APIErrorType.Type = APIErrorType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<ResultType> where ResultType == APIResult<APISuccessType, APIErrorType> {
		let resultProcessor = HTTPStatusCodeCheckResultProcessor()
			.flatMap(
				DecodeHTTPContentResultProcessor<APISuccessType>(decoders: decoders, processingQueue: SyncBlockDispatcher())
					.map{ v in APIResult<APISuccessType, APIErrorType>.success(v) }
			)
			.flatMapError(
				RecoverHTTPStatusCodeCheckErrorResultProcessor()
					.flatMap(DecodeHTTPContentResultProcessor<APIErrorType>(decoders: decoders, processingQueue: SyncBlockDispatcher()))
					.map{ APIResult<APISuccessType, APIErrorType>.failure($0) }
			)
		return URLRequestDataOperation<APIResult<APISuccessType, APIErrorType>>(
			request: urlRequest, session: session, requestProcessors: requestProcessors,
			urlResponseValidators: [/* URL Response Validators do not make much sense for an API call */],
			resultProcessor: resultProcessor,
			retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APISuccessType : Decodable, APIErrorType : Decodable>(
		baseURL: URL, path: String, method: String = "GET", session: URLSession = .shared,
		successType: APISuccessType.Type = APISuccessType.self, errorType: APIErrorType.Type = APIErrorType.self,
		decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType == APIResult<APISuccessType, APIErrorType> {
		return try Self.forAPIRequest(
			baseURL: baseURL, path: path, method: method, urlParameters: nil as Int8?, httpBody: nil as Int8?, session: session,
			successType: successType, errorType: errorType,
			decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APISuccessType : Decodable, APIErrorType : Decodable, URLParamtersType : Encodable>(
		baseURL: URL, path: String, method: String = "GET", urlParameters: URLParamtersType?, session: URLSession = .shared,
		successType: APISuccessType.Type = APISuccessType.self, errorType: APIErrorType.Type = APIErrorType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType == APIResult<APISuccessType, APIErrorType> {
		return try Self.forAPIRequest(
			baseURL: baseURL, path: path, method: method, urlParameters: urlParameters, httpBody: nil as Int8?, session: session,
			successType: successType, errorType: errorType,
			parameterEncoder: parameterEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APISuccessType : Decodable, APIErrorType : Decodable, HTTPBodyType : Encodable>(
		baseURL: URL, path: String, method: String = "POST", httpBody: HTTPBodyType?, session: URLSession = .shared,
		successType: APISuccessType.Type = APISuccessType.self, errorType: APIErrorType.Type = APIErrorType.self,
		bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType == APIResult<APISuccessType, APIErrorType> {
		return try Self.forAPIRequest(
			baseURL: baseURL, path: path, method: method, urlParameters: nil as Int8?, httpBody: httpBody, session: session,
			successType: successType, errorType: errorType,
			bodyEncoder: bodyEncoder, decoders: decoders,
			requestProcessors: requestProcessors, retryProviders: retryProviders
		)
	}
	
	static func forAPIRequest<APISuccessType : Decodable, APIErrorType : Decodable, URLParamtersType : Encodable, HTTPBodyType : Encodable>(
		baseURL: URL, path: String, method: String = "GET", urlParameters: URLParamtersType?, httpBody: HTTPBodyType?, session: URLSession = .shared,
		successType: APISuccessType.Type = APISuccessType.self, errorType: APIErrorType.Type = APIErrorType.self,
		parameterEncoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder, bodyEncoder: HTTPContentEncoder = URLRequestOperationConfig.defaultAPIRequestBodyEncoder, decoders: [HTTPContentDecoder] = URLRequestOperationConfig.defaultAPIResponseDecoders,
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDataOperation<ResultType> where ResultType == APIResult<APISuccessType, APIErrorType> {
		let url = baseURL.appendingPathComponent(path)
		var request = try URLRequest(url: urlParameters.flatMap{ try url.addingQueryParameters(from: $0, encoder: parameterEncoder) } ?? url)
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
