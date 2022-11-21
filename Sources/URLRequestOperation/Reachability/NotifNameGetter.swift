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

#if os(tvOS) || os(iOS)
import Foundation
import UIKit



@objc
internal final class NotifNameGetter : NSObject {
	
	private static let notifNameGetter = NotifNameGetter()
	
	static var didEnterBackgroundNotifName: Notification.Name {
		notifNameGetter.lock.lock()
		if let n = notifNameGetter.cachedDidEnterBackgroundNotifName {
			notifNameGetter.lock.unlock()
			return n
		}
		
		/* The call below should be called on the main thread.
		 * We __will__ get a diagnostic at runtime telling us this should’ve been called on the main thread.
		 * However, I _cannot_ call it on the main thread because I have to be sync.
		 * Also, we’re litterally retrieving the value of a constant, so there’s NO problem doing this from whatever thread.
		 * IMHO it’s `UIApplication.*Notification` that should not have been marked as @MainActor………
		 *
		 * The lock we’ve locked at the beginning of the function will be unlocked in the call below. */
		notifNameGetter.perform(#selector(NotifNameGetter.getDidEnterBackgroundNotifName))
		
		/* The lock is unlocked here.
		 * However we can still access the following variable: as soon as it is set, it becomes r/o. */
		return notifNameGetter.cachedDidEnterBackgroundNotifName!
	}
	
	static var willEnterForegroundNotifName: Notification.Name {
		notifNameGetter.lock.lock()
		if let n = notifNameGetter.cachedWillEnterForegroundNotifName {
			notifNameGetter.lock.unlock()
			return n
		}
		
		notifNameGetter.perform(#selector(NotifNameGetter.getWillEnterForegroundNotifName))
		return notifNameGetter.cachedWillEnterForegroundNotifName!
	}
	
	private let lock = NSLock()
	
	private var cachedDidEnterBackgroundNotifName: Notification.Name?
	private var cachedWillEnterForegroundNotifName: Notification.Name?
	
	@objc @MainActor
	private func getDidEnterBackgroundNotifName() {
		cachedDidEnterBackgroundNotifName = UIApplication.didEnterBackgroundNotification
		lock.unlock()
	}
	
	@objc @MainActor
	private func getWillEnterForegroundNotifName() {
		cachedWillEnterForegroundNotifName = UIApplication.willEnterForegroundNotification
		lock.unlock()
	}
}
#endif
