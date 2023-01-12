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
	
	/**
	 This is used for notifying the request operation a retry helper failed.
	 The retry helper that fails should set this to a non-nil value, then call `retryNow()`. */
	var retryError: Error? {get set}
	
}


public extension URLRequestOperation {
	
}
