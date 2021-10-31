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
internal let opIdQueue = DispatchQueue(label: "com.happn.URLRequestOperation.OperationID")
internal var latestURLOperationIdentifier = -1
#endif

public protocol URLRequestOperation : RetryingOperation {
	
#if DEBUG
	var urlOperationIdentifier: Int {get}
#else
	var urlOperationIdentifier: UUID {get}
#endif
	
}

internal extension URLRequestOperation {
	
	static func isNotFinishedOrCancelledError(_ error: Error?) -> Bool {
		switch error as? URLRequestOperationError {
			case .operationNotFinished?: return true
			case .operationCancelled?:   return true
			default:                     return false
		}
	}
	
	static func isCancelledError(_ error: Error) -> Bool {
		switch error as? URLRequestOperationError {
			case .operationCancelled?: return true
			default:                   return false
		}
	}
	
}
