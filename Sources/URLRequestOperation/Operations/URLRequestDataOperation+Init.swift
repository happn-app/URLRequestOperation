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
#if canImport(os)
import os.log
#endif



public extension URLRequestDataOperation {
	
//	convenience init(
//		request: URLRequest, session: URLSession = .shared,
//		requestProcessors: [RequestProcessor] = [],
//		urlResponseValidators: [URLResponseValidator] = [],
//		resultProcessor: AnyResultProcessor<Data, Data> = .identity(),
//		retryProviders: [RetryProvider] = []
//	) where ResultType == Data {
//		self.init(request: request, session: session, requestProcessors: requestProcessors, urlResponseValidators: urlResponseValidators, resultProcessor: resultProcessor, retryProviders: retryProviders)
//	}
	
	/* Designated for API */
	static func forAPIRequest<APISuccessType : Decodable, APIErrorType : Decodable>(
		successType: APISuccessType.Type = APISuccessType.self, errorType: APIErrorType.Type = APIErrorType.self,
		urlRequest: URLRequest, decoders: [HTTPContentDecoder] = [JSONDecoder()], session: URLSession = .shared,
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
	
//	static func forDecodable<ResultType : Decodable>(
//		apiRoot: URL, path: String, method: String = "GET",
//		decoders: [HTTPContentDecoder],
//		session: URLSession = .shared, requestProcessors: [RequestProcessor] = []
//	) -> URLRequestDataOperation<ResultType> {
//
//	}
//
//	static func forAPICallWithBody<BodyType : Encodable, ResultType : Decodable>(
//		apiRoot: URL, path: String,
//		method: String = "POST", body: BodyType,
//		encoder: HTTPContentEncoder, decoders: [HTTPContentDecoder],
//		session: URLSession = .shared, requestProcessors: [RequestProcessor] = []
//	) -> URLRequestDataOperation<ResultType> {
//	}
	
}
