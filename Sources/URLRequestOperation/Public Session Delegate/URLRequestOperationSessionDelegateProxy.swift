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
#if canImport(os)
import os.log
#endif



#if canImport(ObjectiveC)
/* Inspired by https://github.com/kean/Pulse/blob/cc6c8dec134b387dbdb6f29ab2f4b0373c442c80/Pulse/Sources/PulseCore/URLSessionProxyDelegate.swift */
public final class URLRequestOperationSessionDelegateProxy : URLRequestOperationSessionDelegate {
	
	public var originalDelegate: URLSessionDelegate
	
	public init(_ originalDelegate: URLSessionDelegate) {
		self.originalDelegate = originalDelegate
	}
	
	public override func responds(to aSelector: Selector!) -> Bool {
		return originalDelegate.responds(to: aSelector) || super.responds(to: aSelector)
	}
	
	public override func forwardingTarget(for aSelector: Selector!) -> Any? {
		return originalDelegate.responds(to: aSelector) ? originalDelegate : super.forwardingTarget(for: aSelector)
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	public final override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		/* We do _not_ call super for that one; instead we will call the “task delegate” ourselves.
		 * We do this because we already need to get the task delegate to check if we have to override the completion handler
		 * and we want to avoid getting it twice if possible. */
		let d = delegates.taskDelegateForTask(dataTask)
#if !canImport(FoundationNetworking)
		d?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: { _ in })
#else
		d?.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: { _ in })
#endif
		let newCompletion: (URLSession.ResponseDisposition) -> Void
		if let op = d as? URLRequestOperation {
			newCompletion = { responseDisposition in
				switch responseDisposition {
					case .allow, .cancel, .becomeDownload: ()
#if !canImport(FoundationNetworking)
					case .becomeStream: ()
#endif
					@unknown default:
#if canImport(os)
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							URLRequestOperationConfig.oslog.flatMap{ os_log("URL Op id %ld: Unknown response disposition %ld returned for a task managed by URLRequestOperation. The operation will probably fail.", log: $0, type: .info, op.urlOperationIdentifier, responseDisposition.rawValue) }}
#endif
						URLRequestOperationConfig.logger?.warning("URL Op id \(op.urlOperationIdentifier): Unknown response disposition \(responseDisposition) returned for a task managed by URLRequestOperation. The operation will probably fail.")
				}
				completionHandler(responseDisposition)
			}
		} else {
			newCompletion = completionHandler
		}
		(originalDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: newCompletion) ?? completionHandler(.allow)
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
#if !canImport(FoundationNetworking)
	@available(macOS 10.11, *)
	public final override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
		super.urlSession(session, dataTask: dataTask, didBecome: streamTask)
		(originalDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didBecome: streamTask)
	}
#endif
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	public final override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		super.urlSession(session, dataTask: dataTask, didBecome: downloadTask)
		(originalDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didBecome: downloadTask)
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	public final override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		super.urlSession(session, dataTask: dataTask, didReceive: data)
		(originalDelegate as? URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	public final override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		super.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
		(originalDelegate as? URLSessionDownloadDelegate)?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
	}
	
	/** Method is open, but super must be called to call the URLRequestOperation delegate. */
	public final override func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		super.urlSession(session, task: task, didCompleteWithError: error)
		(originalDelegate as? URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
	}
	
}
#endif
