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

#if canImport(AppKit)
import AppKit
public typealias Image = NSImage
#elseif canImport(UIKit)
import UIKit
public typealias Image = UIImage
#endif



#if canImport(AppKit) || canImport(UIKit)

public extension URLRequestDataOperation {
	
	static func forImage(
		urlRequest: URLRequest, session: URLSession = .shared,
		resultProcessingDispatcher: BlockDispatcher = SyncBlockDispatcher(),
		requestProcessors: [RequestProcessor] = [], retryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	) -> URLRequestDataOperation<Image> {
		return URLRequestDataOperation<Image>(
			request: urlRequest, session: session, requestProcessors: requestProcessors,
			urlResponseValidators: [HTTPStatusCodeURLResponseValidator()],
			resultProcessor: DecodeDataResultProcessor(decoder: dataToImage, processingQueue: resultProcessingDispatcher).erased,
			retryProviders: [UnretriedErrorsRetryProvider.forStatusCodes(), UnretriedErrorsRetryProvider.forImageConversion()] + retryProviders
		)
	}
	
	private static func dataToImage(_ data: Data) throws -> Image {
		guard let image = Image(data: data) else {
			throw Err.cannotConvertToImage(data)
		}
		return image
	}
	
}

#endif
