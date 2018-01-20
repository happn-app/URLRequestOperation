/*
 * URLRequestOperationSessionDelegate.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 1/19/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation



open class URLRequestOperationSessionDelegate : GenericURLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didReceive: data)
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		taskDelegateForTask(task)?.urlSession?(session, task: task, didCompleteWithError: error)
	}
	
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		taskDelegateForTask(downloadTask)?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
	}
	
}
