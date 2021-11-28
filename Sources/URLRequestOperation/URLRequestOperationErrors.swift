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

import MediaType



/** All of the errors thrown by the module should have this type. */
public enum URLRequestOperationError : Error {
	
	case operationNotFinished
	case operationCancelled
	
	/** All errors from request processors are wrapped in this error. */
	case requestProcessorError(Error)
	/** All errors from response validators are wrapped in this error. */
	case responseValidatorError(Error)
	/** All errors from result processors are wrapped in this error. */
	case resultProcessorError(Error)
	
	public var postProcessError: Error? {
		switch self {
			case .responseValidatorError(let e): return e
			case .resultProcessorError(let e): return e
			default: return nil
		}
	}
	
	/**
	 When there is an issue converting between `URL` and `URLComponents`.
	 Thrown by the  `URL` extension method ``addingQueryParameters(from:, encoder:)``.
	 
	 This error should never happen, but technically can (if I understand correctly such failure can occur because `URL` and `URLComponents` do not parse URLs using the same RFCs). */
	case conversionBetweenURLAndURLComponents
	
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
	public struct DataConversionFailed : Error {
		
		var data: Data
		var underlyingError: Error?
		
	}
	
	/** Error that can be thrown by ``HTTPStatusCodeURLResponseValidator`` and ``HTTPStatusCodeCheckResultProcessor``. */
	public struct UnexpectedStatusCode : Error {
		
		var expected: Set<Int>
		var actual: Int?
		
		var httpBody: Data?
		
	}
	
}

typealias Err = URLRequestOperationError
