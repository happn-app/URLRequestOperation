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



public extension URLRequestDownloadOperation {
	
	/* Designated for opening */
	static func forReadingFile(
		request: URLRequest, session: URLSession = .shared,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [],
		retryableStatusCodes: Set<Int> = URLRequestOperationConfig.defaultDownloadRetryableStatusCodes,
		retryProviders: [RetryProvider] = URLRequestOperationConfig.defaultDownloadRetryProviders
	) -> URLRequestDownloadOperation<ResultType> where ResultType == FileHandle {
		return URLRequestDownloadOperation(
			request: request, session: session,
			task: nil,
			requestProcessors: requestProcessors,
			urlResponseValidators: [HTTPStatusCodeURLResponseValidator()],
			resultProcessor: URLToFileHandleResultProcessor(processingQueue: resultProcessingDispatcher).erased,
			retryProviders: [UnretriedErrorsRetryProvider.forWhitelistedStatusCodes(retryableStatusCodes), UnretriedErrorsRetryProvider.forFileHandleFromDownload()] + retryProviders
		)
	}
	
	static func forReadingFile(
		url: URL, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [],
		retryableStatusCodes: Set<Int> = URLRequestOperationConfig.defaultDownloadRetryableStatusCodes,
		retryProviders: [RetryProvider] = URLRequestOperationConfig.defaultDownloadRetryProviders
	) -> URLRequestDownloadOperation<ResultType> where ResultType == FileHandle {
		var request = URLRequest(url: url, cachePolicy: cachePolicy)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		return Self.forReadingFile(
			request: request, session: session,
			resultProcessingDispatcher: resultProcessingDispatcher,
			requestProcessors: requestProcessors,
			retryableStatusCodes: retryableStatusCodes, retryProviders: retryProviders
		)
	}
	
}
