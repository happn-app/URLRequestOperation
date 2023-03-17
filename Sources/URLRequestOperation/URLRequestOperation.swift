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



#if DEBUG
internal enum LatestURLOpIDContainer {
	static let opIdQueue = DispatchQueue(label: "com.happn.URLRequestOperation.OperationID")
	@SafeGlobal static var latestURLOperationIdentifier = -1
}

public typealias URLRequestOperationID = Int
#else
public typealias URLRequestOperationID = UUID
#endif


public protocol URLRequestOperation : RetryingOperation, Sendable {
	
	var urlOperationIdentifier: URLRequestOperationID {get}
	
	/** The date at which the URLRequestOperation has been started. */
	var startDate: Date? {get}
	/**
	 The date at which a base operation failed in the URLRequestOperation.
	 If this is non-nil, it does not mean the operation failed as it can be retried. */
	var latestFailureDate: Date? {get}
	/** The start date of the latest try of the operation. */
	var latestTryStartDate: Date? {get}
	
	/**
	 This is used for notifying the request operation a retry helper failed.
	 
	 The retry helper that fails should set this to a non-nil value, then call `retryNow()`.
	 The URLRequestOperation will then fail the base operation directly without even launching the URLTask,
	  then fallback to the retry handler provider normally as if a URLTask had failed. */
	var retryError: Error? {get set}
	
}


internal enum LoggedWarnings {
	
	@SafeGlobal static var weirdSessionSetupWithURLRequestOperationDelegate = false
	
	@SafeGlobal static var dataOperationWithSessionDelegateNotURLRequestOperationSessionDelegate = false
	@SafeGlobal static var dataOperationWithSessionDelegateNil = false
	
	@SafeGlobal static var downloadOperationWithSessionDelegateNotURLRequestOperationSessionDelegate = false
	@SafeGlobal static var downloadOperationWithSessionDelegateNil = false
	
}
