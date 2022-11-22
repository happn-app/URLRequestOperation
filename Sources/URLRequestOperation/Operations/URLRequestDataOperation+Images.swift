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

/* UIKit check first for Mac Catalyst case. */
#if canImport(UIKit)
import UIKit
public typealias Image = UIImage
#elseif canImport(AppKit)
@preconcurrency import AppKit /* We @preconcurrency because NSImage does not seem Sendable. We _assume_ it’s an annotation issue, but that’s far from being a given… */
public typealias Image = NSImage
#endif



#if canImport(AppKit) || canImport(UIKit)

public extension URLRequestDataOperation {
	
	static func forImage(
		urlRequest: URLRequest, session: URLSession = .shared,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [],
		retryableStatusCodes: Set<Int> = URLRequestOperationConfig.defaultImageRetryableStatusCodes,
		retryProviders: [RetryProvider] = URLRequestOperationConfig.defaultImageRetryProviders
	) -> URLRequestDataOperation<ResultType> where ResultType == Image {
		return URLRequestDataOperation<Image>(
			request: urlRequest, session: session, requestProcessors: requestProcessors,
			urlResponseValidators: [HTTPStatusCodeURLResponseValidator()],
			resultProcessor: DecodeDataResultProcessor(decoder: dataToImage, processingQueue: resultProcessingDispatcher).erased,
			retryProviders: [UnretriedErrorsRetryProvider.forWhitelistedStatusCodes(retryableStatusCodes), UnretriedErrorsRetryProvider.forDataConversion()] + retryProviders
		)
	}
	
	static func forImage(
		url: URL, headers: [String: String?] = [:], cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy, session: URLSession = .shared,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [],
		retryableStatusCodes: Set<Int> = URLRequestOperationConfig.defaultImageRetryableStatusCodes,
		retryProviders: [RetryProvider] = URLRequestOperationConfig.defaultImageRetryProviders
	) -> URLRequestDataOperation<ResultType> where ResultType == Image {
		var request = URLRequest(url: url, cachePolicy: cachePolicy)
		for (key, val) in headers {request.setValue(val, forHTTPHeaderField: key)}
		return Self.forImage(
			urlRequest: request, session: session,
			resultProcessingDispatcher: resultProcessingDispatcher,
			requestProcessors: requestProcessors,
			retryableStatusCodes: retryableStatusCodes, retryProviders: retryProviders
		)
	}
	
	@Sendable
	private static func dataToImage(_ data: Data) throws -> Image {
		guard let image = Image(data: data) else {
			throw ImageConversionError(data: data)
		}
		return image
	}
	
}


public struct ImageConversionError : Error {
	
	public let data: Data
	
	public init(data: Data) {
		self.data = data
	}
	
}

#endif
