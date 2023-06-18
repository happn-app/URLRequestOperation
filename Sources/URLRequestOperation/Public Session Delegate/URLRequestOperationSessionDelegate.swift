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

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



open class URLRequestOperationSessionDelegate : NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
	
	internal var delegates = URLSessionDelegates()
	
	/** Method is open, but if overwritten, care must be taken to merge the result from the task delegate for the given task. */
	open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
#if !canImport(FoundationNetworking)
		if let delegate = delegates.taskDelegateForTask(dataTask), delegate.responds(to: #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:))) {
			delegate.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
		} else {
			completionHandler(.allow)
		}
#else
		if let delegate = delegates.taskDelegateForTask(dataTask) {
			delegate.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
		} else {
			completionHandler(.allow)
		}
#endif
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
#if !canImport(FoundationNetworking)
	@available(macOS 10.11, *)
	open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		delegates.taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
	}
#endif
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
#if !canImport(FoundationNetworking)
		delegates.taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
#else
		delegates.taskDelegateForTask(dataTask)?.urlSession(session, dataTask: dataTask, didBecome: downloadTask)
#endif
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
#if !canImport(FoundationNetworking)
		delegates.taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didReceive: data)
#else
		delegates.taskDelegateForTask(dataTask)?.urlSession(session, dataTask: dataTask, didReceive: data)
#endif
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		delegates.taskDelegateForTask(downloadTask)?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
#if !canImport(FoundationNetworking)
		delegates.taskDelegateForTask(task)?.urlSession?(session, task: task, didCompleteWithError: error)
#else
		delegates.taskDelegateForTask(task)?.urlSession(session, task: task, didCompleteWithError: error)
#endif
	}
	
}
