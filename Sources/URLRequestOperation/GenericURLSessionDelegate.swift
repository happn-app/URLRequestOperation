/*
 * GenericURLSessionDelegate.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 12/14/15.
 * Copyright © 2015 happn. All rights reserved.
 */

import Foundation



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
open class GenericURLSessionDelegate: NSObject, URLSessionDelegate {
	
	#if !os(Linux)
		var taskToDelegate = NSMapTable<URLSessionTask, URLSessionTaskDelegate>.weakToWeakObjects()
	#else
		var taskToDelegate = LinuxWeakToWeakForGenericURLSessionDelegateMapTable()
	#endif
	
	public func setTaskDelegate(_ delegate: AnyObject & URLSessionTaskDelegate, forTask task: URLSessionTask) {
		taskToDelegate.setObject(delegate, forKey: task)
	}
	
	public func taskDelegateForTask(_ task: URLSessionTask) -> URLSessionTaskDelegate? {
		return taskToDelegate.object(forKey: task)
	}
	
//	@objc(dataTaskDelegateForDataTask:)
	public func taskDelegateForTask(_ task: URLSessionDataTask) -> URLSessionDataDelegate? {
		return taskToDelegate.object(forKey: task) as? URLSessionDataDelegate
	}
	
//	@objc(downloadTaskDelegateForDownloadTask:)
	public func taskDelegateForTask(_ task: URLSessionDownloadTask) -> URLSessionDownloadDelegate? {
		return taskToDelegate.object(forKey: task) as? URLSessionDownloadDelegate
	}
	
	@available(OSX 10.11, iOS 9.0, *)
//	@objc(streamTaskDelegateForStreamTask:)
	public func taskDelegateForTask(_ task: URLSessionStreamTask) -> URLSessionStreamDelegate? {
		return taskToDelegate.object(forKey: task) as? URLSessionStreamDelegate
	}
	
}
