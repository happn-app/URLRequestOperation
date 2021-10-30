import Foundation

import RetryingOperation



extension NSNotification.Name {
	
	public static let URLRequestOperationDidSucceedOperation = NSNotification.Name(rawValue: "com.happn.URLRequestOperation.DidSucceedRequest")
	
}


public final class OtherSuccessRetryHelper : RetryHelper {
	
	public static let requestSucceededNotifUserInfoHostKey = "Host"
	
	public init?(host h: String?, operation op: RetryingOperation) {
		guard let h = h else {return nil}
		operation = op
		host = h
	}
	
	public func setup() {
		assert(otherSuccessObserver == nil)
		otherSuccessObserver = NotificationCenter.default.addObserver(forName: .URLRequestOperationDidSucceedOperation, object: nil, queue: nil, using: { notif in
			let succeededHost = notif.userInfo?[Self.requestSucceededNotifUserInfoHostKey] as? String
			guard succeededHost == self.host else {return}
			
//#if canImport(os)
//			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
//				URLRequestOperationConfig.oslog.flatMap{ os_log("URL Op id %d: Got an URL operation succeeded with same host as me. Forcing retrying sooner.", log: $0, type: .debug, self.operation.urlOperationIdentifier) }}
//#endif
//			URLRequestOperationConfig.logger?.debug("URL Op id \(self.operation.urlOperationIdentifier): Got an URL operation succeeded with same host as me. Forcing retrying sooner.")
			self.operation.retry(in: SimpleErrorRetryProvider.exponentialBackoffTimeForIndex(1))
		})
	}
	
	public func teardown() {
		NotificationCenter.default.removeObserver(otherSuccessObserver! /* Internal error if observer is nil */, name: .URLRequestOperationDidSucceedOperation, object: nil)
		otherSuccessObserver = nil
	}
	
	private let host: String
	private let operation: RetryingOperation
	private var otherSuccessObserver: NSObjectProtocol?
	
}
