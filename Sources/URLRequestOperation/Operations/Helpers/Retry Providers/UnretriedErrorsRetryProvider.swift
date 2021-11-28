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

import RetryingOperation



public struct UnretriedErrorsRetryProvider : RetryProvider {
	
	public static func forStatusCodes(_ codes: Set<Int> = Set(400..<500)) -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let statusCodeError = (err as? Err)?.postProcessError as? Err.UnexpectedStatusCode else {
				return false
			}
			return statusCodeError.actual.flatMap{ codes.contains($0) } ?? true
		}
	}
	
	public static func forHTTPContentDecoding() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = (err as? Err)?.postProcessError else {
				return false
			}
			return postProcessError is DecodeHTTPContentResultProcessorError
		}
	}
	
	public static func forDataConversion() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = (err as? Err)?.postProcessError else {
				return false
			}
			return postProcessError is Err.DataConversionFailed
		}
	}
	
	public static func forDownload() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = (err as? Err)?.postProcessError else {
				return false
			}
			return postProcessError is URLMoveResultProcessorError
		}
	}
	
	public static func forFileHandleFromDownload() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			guard let postProcessError = (err as? Err)?.postProcessError else {
				return false
			}
			return postProcessError is URLToFileHandleResultProcessorError
		}
	}
	
	public let isBlacklistedError: (Error) -> Bool
	
	public init(isBlacklistedError: @escaping (Error) -> Bool) {
		self.isBlacklistedError = isBlacklistedError
	}
	
	public func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?? {
		if isBlacklistedError(error) {
			return .some(nil)
		}
		return nil
	}
	
}
