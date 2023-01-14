/*
Copyright 2019-2021 happn

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

import MediaType



/** All of the errors thrown by the module should have this type. */
public enum URLRequestOperationError : Error, Sendable {
	
	case operationNotFinished
	case operationCancelled
	
	/** All errors from request processors are wrapped in this error. */
	case requestProcessorError(Error)
	/** All errors from response validators are wrapped in this error. */
	case responseValidatorError(Error)
	/** All errors from result processors are wrapped in this error. */
	case resultProcessorError(Error)
	
	case urlSessionError(Error)
	
	case retryError(Error)
	
	/**
	 When there is an issue converting between `URL` and `URLComponents`.
	 Thrown by the `URL` extension method `URL.appendingQueryParameters(from:encoder:)` (but you don’t have access to that).
	 Can also be thrown by creating an `URLRequest*Operation` via one of the convenient method that allows specifying some query parameters to add to the base URL.
	 
	 This error should never happen, but technically can (if I understand correctly such failure can occur because `URL` and `URLComponents` do not parse URLs using the same RFCs). */
	case failedConversionBetweenURLAndURLComponents
	/**
	 Thrown by `addingPathComponentsSafely(_:)`, if (at least) one of the path component is invalid (but you don’t have access to that method).
	 Can also be thrown by creating an `URLRequest*Operation` via one of the convenient method that allows passing a path components to add to the base URL.
	 
	 For now the only way a path component is invalid is if it contains the path separator (`/`). */
	case invalidPathComponent(String)
	
	/**
	 One of these cases that should never happen happened:
	 - URL response **and** error are `nil` from underlying session task;
	 - Task’s response is `nil` in `urlSession(:downloadTask:didFinishDownloadingTo:)`.
	 
	 We provide this in order to avoid crashing instead if one of these do happen.
	 In debug mode, we do crash (assertion failure). */
	case brokenURLSessionContract
	
}

typealias Err = URLRequestOperationError


public extension URLRequestOperationError {
	
	/* MARK: -
	 * Some conveniences for easily accessing sub-errors. */
	
	var preProcessError: Error? {
		switch self {
			case .requestProcessorError(let e): return e
			default:                            return nil
		}
	}
	
	/** Directly access the response validator or result processor error if any. */
	var postProcessError: Error? {
		switch self {
			case .responseValidatorError(let e): return e
			case .resultProcessorError(let e):   return e
			default:                             return nil
		}
	}
	
	var postProcessOrApiUpstreamError: Error? {
		let ret1: Error? = {
			switch self {
				case .responseValidatorError(let e): return e
				case .resultProcessorError(let e):   return e
				default:                             return nil
			}
		}()
		return (ret1 as? APIResultErrorWrapperProtocol)?.upstreamError ?? ret1
	}
	
	var urlSessionError: Error? {
		switch self {
			case .urlSessionError(let e): return e
			default:                      return nil
		}
	}
	
	var retryError: Error? {
		switch self {
			case .retryError(let e): return e
			default:                 return nil
		}
	}
	
}

public extension URLRequestOperationError {
	
	var unexpectedStatusCodeError: UnexpectedStatusCode? {
		return (postProcessOrApiUpstreamError as? UnexpectedStatusCode)
	}
	
	func apiError<APIError : Sendable>(_ apiErrorType: APIError.Type) -> APIError? {
		return apiErrorWrapper(apiErrorType)?.apiError
	}
	
	func apiErrorWrapper<APIError : Sendable>(_ apiErrorType: APIError.Type) -> APIResultErrorWrapper<APIError>? {
		return postProcessError as? APIResultErrorWrapper<APIError>
	}
	
	/* We do not check for URLSession cancellation error because the URLRequestOperations force the result to .operationCancelled when the operation is cancelled. */
	var isCancelledError: Bool {
		switch self {
			case .operationCancelled: return true
			default:                  return false
		}
	}
	
	var isCancelledOrNotFinishedError: Bool {
		switch self {
			case .operationNotFinished: return true
			case .operationCancelled:   return true
			default:                    return false
		}
	}
	
}



/* MARK: -
 * Most of the time the classes/structs declare their own errors in their file directly,
 * but the following structure are re-used and are thus grouped together here. */

/** Error that can be thrown by ``DecodeDataResultProcessor`` and ``DecodeHTTPContentResultProcessor``. */
public struct DataConversionFailed : Error, Sendable {
	
	public var data: Data
	public var underlyingError: Error?
	
}


/** Error that can be thrown by ``HTTPStatusCodeURLResponseValidator`` and ``HTTPStatusCodeCheckResultProcessor``. */
public struct UnexpectedStatusCode : Error, Sendable {
	
	public var expected: Set<Int>
	public var actual: Int?
	
	public var httpBody: Data?
	
	public init(expected: Set<Int>, actual: Int? = nil, httpBody: Data? = nil) {
		self.expected = expected
		self.actual = actual
		self.httpBody = httpBody
	}
	
}


/** A wrapper for an API Error. */
protocol APIResultErrorWrapperProtocol : Error {
	var urlResponse: URLResponse {get}
	var upstreamError: Error? {get}
}

public struct APIResultErrorWrapper<APIError : Sendable> : Error, APIResultErrorWrapperProtocol {
	
	public var apiError: APIError
	
	public var urlResponse: URLResponse
	public var upstreamError: Error?
	
	public init(apiError: APIError, urlResponse: URLResponse, upstreamError: Error? = nil) {
		self.apiError = apiError
		self.urlResponse = urlResponse
		self.upstreamError = upstreamError
	}
	
}
