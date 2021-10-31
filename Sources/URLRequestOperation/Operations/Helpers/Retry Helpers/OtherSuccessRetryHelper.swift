import Foundation
#if canImport(os)
import os.log
#endif

import RetryingOperation



extension NSNotification.Name {
	
	public static let URLRequestOperationDidSucceedOperation = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.DidSucceedRequest")
	
}


public final class OtherSuccessRetryHelper : RetryHelper {
	
	public static let requestSucceededNotifUserInfoHostKey = "Host"
	
	public init?(host h: String?, operation op: URLRequestOperation) {
		guard let h = h else {return nil}
		operation = op
		host = h
	}
	
	public func setup() {
		assert(otherSuccessObserver == nil)
		otherSuccessObserver = NotificationCenter.default.addObserver(forName: .URLRequestOperationDidSucceedOperation, object: nil, queue: nil, using: { notif in
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
	
	public func teardown() {
		NotificationCenter.default.removeObserver(otherSuccessObserver! /* Internal error if observer is nil */, name: .URLRequestOperationDidSucceedOperation, object: nil)
		otherSuccessObserver = nil
	}
	
	private let host: String
	private let operation: URLRequestOperation
	private var otherSuccessObserver: NSObjectProtocol?
	
}
