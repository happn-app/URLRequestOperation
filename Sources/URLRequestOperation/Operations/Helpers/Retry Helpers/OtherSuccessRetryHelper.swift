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
#if canImport(os)
import os.log
#endif

import RetryingOperation



extension NSNotification.Name {
	
	public static let URLRequestOperationDidSucceedURLSessionTask = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.DidSucceedURLSessionTask")
	public static let URLRequestOperationWillSucceedOperation = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.WillSucceedOperation")
	public static let URLRequestOperationWillFinishOperation = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.WillFinishOperation")
	
}


public final class OtherSuccessRetryHelper : RetryHelper, @unchecked Sendable {
	
	public static let requestSucceededNotifUserInfoHostKey = "Host"
	
	public let host: String
	
	public init?(host: String?, monitorSessionTaskSuccessInsteadOfOperationSuccess: Bool = false, operation: URLRequestOperation) {
		guard let host = host else {return nil}
		self.host = host
		self.notifName = monitorSessionTaskSuccessInsteadOfOperationSuccess ? .URLRequestOperationDidSucceedURLSessionTask : .URLRequestOperationWillSucceedOperation
		self.operation = operation
	}
	
	public func setup() {
		otherSuccessLock.withLock{
			assert(otherSuccessObserver == nil)
			otherSuccessObserver = NotificationCenter.default.addObserver(forName: notifName, object: nil, queue: nil, using: { notif in
				let succeededHost = notif.userInfo?[Self.requestSucceededNotifUserInfoHostKey] as? String
				guard succeededHost == self.host else {return}
				
#if canImport(os)
				if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
					Conf.oslog.flatMap{ os_log("URLOpID %{public}@: Got an URL operation succeeded with same host as me. Forcing retrying sooner.", log: $0, type: .debug, String(describing: self.operation.urlOperationIdentifier)) }}
#endif
				Conf.logger?.debug("Got an URL operation succeeded with same host as me. Forcing retrying sooner.", metadata: [LMK.operationID: "\(self.operation.urlOperationIdentifier)"])
				self.operation.retry(in: NetworkErrorRetryProvider.exponentialBackoffTimeForIndex(1))
			})
		}
	}
	
	public func teardown() {
		otherSuccessLock.withLock{
			NotificationCenter.default.removeObserver(otherSuccessObserver! /* Internal error if observer is nil */, name: notifName, object: nil)
			otherSuccessObserver = nil
		}
	}
	
	private let operation: URLRequestOperation
	
	private let notifName: Notification.Name
	
	private let otherSuccessLock = NSLock()
	private var otherSuccessObserver: NSObjectProtocol?
	
}
