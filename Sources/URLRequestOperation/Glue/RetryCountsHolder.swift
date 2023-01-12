/*
Copyright 2023 happn

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



/* Just like SafeGlobal, we use the same lock for all RetryCountsHolder instances.
 * We could use one lock per instance instead but there’s no need AFAICT. */
private let safeGlobalLock = NSLock()

public class RetryCountsHolder : @unchecked Sendable {
	
	public init(setupWillFinishObserver: Bool = true, resetTryCountNotifName: Notification.Name? = nil, notificationCenter: NotificationCenter = .default) {
		notifObservers = {
			var res = [NSObjectProtocol]()
			if setupWillFinishObserver {
				res.append(notificationCenter.addObserver(forName: .URLRequestOperationWillFinishOperation, object: nil, queue: nil, using: { [weak self] n in
					self?[n] = nil
				}))
			}
			if let resetTryCountNotifName {
				res.append(notificationCenter.addObserver(forName: resetTryCountNotifName, object: nil, queue: nil, using: { [weak self] n in
					self?[n] = 0
				}))
			}
			return res
		}()
	}
	
	public subscript(notification: Notification) -> Int? {
		get {
			guard let urlOpID = notification.object as? URLRequestOperationID else {
				Conf.logger?.warning("Notif object is not an URLRequestOperationID in RetryCountsHolder subscript.", metadata: ["notification_object": .init(stringLiteral: String(describing: notification.object))])
				return nil
			}
			return self[urlOpID]
		}
		set {
			guard let urlOpID = notification.object as? URLRequestOperationID else {
				Conf.logger?.warning("Notif object is not an URLRequestOperationID in RetryCountsHolder subscript.", metadata: ["notification_object": .init(stringLiteral: String(describing: notification.object))])
				return
			}
			self[urlOpID] = newValue
		}
	}
	
	public subscript(operationID: URLRequestOperationID) -> Int? {
		get {safeGlobalLock.withLock{ retryCounts[operationID] }}
		set {safeGlobalLock.withLock{ retryCounts[operationID] = newValue }}
	}
	
	public subscript(operationID: URLRequestOperationID, default defaultValue: Int) -> Int {
		get {safeGlobalLock.withLock{ retryCounts[operationID, default: defaultValue] }}
		set {safeGlobalLock.withLock{ retryCounts[operationID, default: defaultValue] = newValue }}
	}
	
	private var retryCounts = [URLRequestOperationID: Int]()
	/* var because it is otherwise impossible to create the observers because it would use self before it is initialized (not really but the compiler does not know that). */
	private var notifObservers = [NSObjectProtocol]()
	
}
