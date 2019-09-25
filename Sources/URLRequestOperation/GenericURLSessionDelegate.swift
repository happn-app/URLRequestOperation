/*
Copyright 2019 happn

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



/**
A helper to forward NSURLSession's delegate message to another observer for a
given task.

This abstract class does nothing by itself and does not implement any of the
NSURLSessionDelegate methods. You have to implement the ones you want in your
subclasses.

The generic URL session delegate is merely a convenience to help forward the
actual implementation of your delegates to the correct destination depending on
the NSURLSessionTask object given in parameter to the delegate methods.

The URLSessionDelegates and URLSessionTask are not retained by this class (weak
references). */
open class GenericURLSessionDelegate : NSObject, URLSessionDelegate {
	
	public func setTaskDelegate(_ delegate: AnyObject & URLSessionTaskDelegate, forTask task: URLSessionTask) {
		queueSyncForMapTable.sync{ taskToDelegate.setObject(delegate, forKey: task) }
	}
	
	public func taskDelegateForTask(_ task: URLSessionTask) -> URLSessionTaskDelegate? {
		return queueSyncForMapTable.sync{ taskToDelegate.object(forKey: task) }
	}
	
//	@objc(dataTaskDelegateForDataTask:)
	public func taskDelegateForTask(_ task: URLSessionDataTask) -> URLSessionDataDelegate? {
		return queueSyncForMapTable.sync{ taskToDelegate.object(forKey: task) as? URLSessionDataDelegate }
	}
	
//	@objc(downloadTaskDelegateForDownloadTask:)
	public func taskDelegateForTask(_ task: URLSessionDownloadTask) -> URLSessionDownloadDelegate? {
		return queueSyncForMapTable.sync{ taskToDelegate.object(forKey: task) as? URLSessionDownloadDelegate }
	}
	
	@available(OSX 10.11, iOS 9.0, *)
//	@objc(streamTaskDelegateForStreamTask:)
	public func taskDelegateForTask(_ task: URLSessionStreamTask) -> URLSessionStreamDelegate? {
		return queueSyncForMapTable.sync{ taskToDelegate.object(forKey: task) as? URLSessionStreamDelegate }
	}
	
	private let queueSyncForMapTable = DispatchQueue(label: "com.happn.URLRequestOperation.GenericURLSessionDelegate")
	#if !os(Linux)
		private var taskToDelegate = NSMapTable<URLSessionTask, URLSessionTaskDelegate>.weakToWeakObjects()
	#else
		private var taskToDelegate = LinuxWeakToWeakForGenericURLSessionDelegateMapTable()
	#endif
	
}
