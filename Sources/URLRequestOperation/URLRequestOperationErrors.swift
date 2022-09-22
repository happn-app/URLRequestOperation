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
	
	/** Directly access the response validator or result processor error if any. */
	public var postProcessError: Error? {
		switch self {
			case .responseValidatorError(let e): return e
			case .resultProcessorError(let e): return e
			default: return nil
		}
	}
	
	public var unexpectedStatusCodeError: UnexpectedStatusCode? {
		return postProcessError as? UnexpectedStatusCode
	}
	
	case operationNotFinished
	case operationCancelled
	
	/** All errors from request processors are wrapped in this error. */
	case requestProcessorError(Error)
	/** All errors from response validators are wrapped in this error. */
	case responseValidatorError(Error)
	/** All errors from result processors are wrapped in this error. */
	case resultProcessorError(Error)
	
	/**
	 When there is an issue converting between `URL` and `URLComponents`.
	 Thrown by the  `URL` extension method ``addingQueryParameters(from:, encoder:)`` (but you don’t have access to that).
	 Can also be thrown by creating an `URLRequest*Operation` via one of the convenient method that allows specifying some query parameters to add to the base URL.
	 
	 This error should never happen, but technically can (if I understand correctly such failure can occur because `URL` and `URLComponents` do not parse URLs using the same RFCs). */
	case failedConversionBetweenURLAndURLComponents
	/**
	 Thrown by ``addingPathComponentsSafely(_:)``, if (at least) one of the path component is invalid (but you don’t have access to that method).
	 Can also be thrown by creating an `URLRequest*Operation` via one of the convenient method that allows passing a path components to add to the base URL.
	 
	 For now the only way a path component is invalid is if it contains the path separator (`/`). */
	case invalidPathComponent(String)
	
	/**
	 One of these cases that should never happen happened:
	 - URL response **and** error are `nil` from underlying session task;
	 - Task’s response is `nil` in `urlSession(:downloadTask:didFinishDownloadingTo:)`.
	 
	 We provide this in order to avoid crashing instead if one of these do happen.
	 In debug mode, we do crash (assertion failure). */
	case invalidURLSessionContract
	
	
	/* MARK: -
	 * Most of the time the classes/structs declare their own errors in their file directly,
	 * but the following structure are re-used and are thus grouped together here. */
	
	
	/** Error that can be thrown by ``HTTPStatusCodeURLResponseValidator`` and ``HTTPStatusCodeCheckResultProcessor``. */
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
	public struct APIResultErrorWrapper<APIError> : Error/* Sendable when APIError is Sendable; declared at the end of this file. */ {
		
		public var urlResponse: URLResponse
		public var error: APIError
		
		/** Convenience to get the APIResultErrorWrapper from any Error (the error has to be an URLRequestOperationError, of course). */
		public static func get(from error: Error) -> Self? {
			switch error as? Err {
				case .resultProcessorError(let e)?:
					return e as? Self
					
				default:
					return nil
			}
		}
		
		public init(urlResponse: URLResponse, error: APIError) {
			self.urlResponse = urlResponse
			self.error = error
		}
		
	}
	
}

extension URLRequestOperationError.APIResultErrorWrapper : Sendable where APIError : Sendable {}

typealias Err = URLRequestOperationError
