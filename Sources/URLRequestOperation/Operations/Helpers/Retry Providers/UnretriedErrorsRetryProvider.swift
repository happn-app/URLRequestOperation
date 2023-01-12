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

import RetryingOperation



public struct UnretriedErrorsRetryProvider : RetryProvider {
	
	public static func forBlacklistedStatusCodes(_ codes: Set<Int> = Set(400..<500), blacklistNil: Bool = true) -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let statusCodeError = err.unexpectedStatusCodeError else {
				return false
			}
			return statusCodeError.actual.flatMap{ codes.contains($0) } ?? blacklistNil
		}
	}
	
	public static func forWhitelistedStatusCodes(_ codes: Set<Int> = Set(500..<600), whitelistNil: Bool = false) -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let statusCodeError = err.unexpectedStatusCodeError else {
				return false
			}
			return statusCodeError.actual.flatMap{ !codes.contains($0) } ?? !whitelistNil
		}
	}
	
	public static func forHTTPContentDecoding() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = err.postProcessError else {
				return false
			}
			return postProcessError is DecodeHTTPContentResultProcessorError
		}
	}
	
	public static func forAPIError<APIErrorType>(errorType: APIErrorType.Type = APIErrorType.self, isRetryableBlock: @escaping @Sendable (_ error: APIResultErrorWrapper<APIErrorType>) -> Bool = { _ in false }) -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let apiErrorWrapper = err.postProcessError as? APIResultErrorWrapper<APIErrorType> else {
				return false
			}
			return !isRetryableBlock(apiErrorWrapper)
		}
	}
	
	public static func forDataConversion() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = err.postProcessError else {
				return false
			}
			return postProcessError is DataConversionFailed
		}
	}
	
	public static func forDownload() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = err.postProcessError else {
				return false
			}
			return postProcessError is URLMoveResultProcessorError
		}
	}
	
	public static func forFileHandleFromDownload() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = err.postProcessError else {
				return false
			}
			return postProcessError is URLToFileHandleResultProcessorError
		}
	}
	
	public let isBlacklistedError: @Sendable (URLRequestOperationError) -> Bool
	
	public init(isBlacklistedError: @escaping @Sendable (URLRequestOperationError) -> Bool) {
		self.isBlacklistedError = isBlacklistedError
	}
	
	public func retryHelpers(for request: URLRequest, error: URLRequestOperationError, operation: URLRequestOperation) -> [RetryHelper]?? {
		if isBlacklistedError(error) {
			return .some(nil)
		}
		return nil
	}
	
}
