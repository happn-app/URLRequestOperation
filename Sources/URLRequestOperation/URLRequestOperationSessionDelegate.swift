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



open class URLRequestOperationSessionDelegate : GenericURLSessionDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		#if !os(Linux)
			taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
		#else
			taskDelegateForTask(dataTask)?.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
		#endif
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		#if !os(Linux)
			taskDelegateForTask(dataTask)?.urlSession?(session, dataTask: dataTask, didReceive: data)
		#else
			taskDelegateForTask(dataTask)?.urlSession(session, dataTask: dataTask, didReceive: data)
		#endif
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		#if !os(Linux)
			taskDelegateForTask(task)?.urlSession?(session, task: task, didCompleteWithError: error)
		#else
			taskDelegateForTask(task)?.urlSession(session, task: task, didCompleteWithError: error)
		#endif
	}
	
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		taskDelegateForTask(downloadTask)?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
	}
	
}
