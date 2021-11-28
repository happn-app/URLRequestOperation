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



public extension URLRequestDownloadOperation {
	
	static func forSavingFile(
		request: URLRequest, session: URLSession = .shared,
		destination: URL, moveBehavior: URLMoveResultProcessor.MoveBehavior = .failIfDestinationExists,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) throws -> URLRequestDownloadOperation<ResultType> where ResultType == URL {
		return URLRequestDownloadOperation(
			request: request, session: session,
			task: nil,
			requestProcessors: requestProcessors,
			urlResponseValidators: [HTTPStatusCodeURLResponseValidator()],
			resultProcessor: URLMoveResultProcessor(destinationURL: destination, moveBehavior: moveBehavior, processingQueue: resultProcessingDispatcher).erased,
			retryProviders: [UnretriedErrorsRetryProvider.forStatusCodes(), UnretriedErrorsRetryProvider.forDownload()] + retryProviders
		)
	}
	
//	public convenience init(
//		request: URLRequest, session: URLSession = .shared,
//		requestProcessors: [RequestProcessor] = [],
//		urlResponseValidators: [URLResponseValidator] = [],
//		resultProcessor: AnyResultProcessor<URL, FileHandle> = URLToFileHandleResultProcessor().erased,
//		retryProviders: [RetryProvider] = []
//	) where ResultType == FileHandle {
//		self.init(
//			request: request, session: session,
//			task: nil,
//			requestProcessors: requestProcessors,
//			urlResponseValidators: urlResponseValidators,
//			resultProcessor: resultProcessor,
//			retryProviders: retryProviders
//		)
//	}
//	
//	public convenience init(
//		request: URLRequest, session: URLSession = .shared,
//		requestProcessors: [RequestProcessor] = [],
//		urlResponseValidators: [URLResponseValidator] = [],
//		resultProcessor: AnyResultProcessor<URL, ResultType>,
//		retryProviders: [RetryProvider] = []
//	) {
//		self.init(
//			request: request, session: session,
//			task: nil,
//			requestProcessors: requestProcessors,
//			urlResponseValidators: urlResponseValidators,
//			resultProcessor: resultProcessor,
//			retryProviders: retryProviders
//		)
//	}
	
}
