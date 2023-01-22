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

import URLRequestOperation


class SessionDelegate : NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
	
	let delegateId: Int
	
	init(id: Int) {
		delegateId = id
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		print("delegate \(delegateId): task ended; error: \(String(describing: error))")
	}
	
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		print("delegate \(delegateId): data received")
	}
	
	@available(macOS 10.12, *)
	func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
		print("delegate \(delegateId): metrics received")
	}
	
}

/* ************************************************************ */

URLRequestOperationConfig.maxRequestBodySizeToLog = .max
URLRequestOperationConfig.maxResponseBodySizeToLog = .max

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
let session = URLSession(configuration: .ephemeral, delegate: URLRequestOperationSessionDelegateProxy(SessionDelegate(id: 1)), delegateQueue: nil)
#else
let session = URLSession(configuration: .ephemeral, delegate: URLRequestOperationSessionDelegate(), delegateQueue: nil)
/* This one crashes on Linux for whatever reason:
 *    Metadata allocator corruption: allocation is NULL. curState: {(nil), 33872} - curStateReRead: {(nil), 33872} - newState: {0x30, 33824} - allocatedNewPage: false - requested size: 48 - sizeWithHeader: 48 - alignment: 8 - Tag: 14 */
//let session = URLSession(configuration: .ephemeral, delegate: SessionDelegate(id: 1), delegateQueue: nil)
#endif

//let t1 = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!)
//t1.resume()
//Thread.sleep(forTimeInterval: 1)
//
//let t2 = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!, completionHandler: { data, response, error in
//	print("task ended in handler; error \(String(describing: error))")
//})
//t2.resume()
//Thread.sleep(forTimeInterval: 1)
//
//if #available(macOS 12.0, tvOS 15.0, iOS 15.0, watchOS 8.0, *) {
//	let delegate = SessionDelegate(id: 2)
//	let t3 = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!)
//	t3.delegate = delegate
//
//	t3.resume()
//	Thread.sleep(forTimeInterval: 1)
//
//	let t4 = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!, completionHandler: { data, response, error in
//		print("task ended in handler; error \(String(describing: error))")
//	})
//	t4.delegate = delegate
//	t4.resume()
//	Thread.sleep(forTimeInterval: 1)
//}

let q = OperationQueue()
let request = URLRequest(url: URL(string: "https://frostland.fr/http-tests/200-empty")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0.5)
let operation1 = URLRequestDataOperation<Data>(
	request: request, session: session,
	requestProcessors: [],
	urlResponseValidators: [HTTPStatusCodeURLResponseValidator(expectedCodes: Set(arrayLiteral: 500))],
	resultProcessor: .identity(),
	retryProviders: [
		UnretriedErrorsRetryProvider(isBlacklistedError: { $0.urlSessionError == nil }),
		NetworkErrorRetryProvider(maximumNumberOfRetries: 5)
	]
)
let operation2 = URLRequestDownloadOperation<FileHandle>(
	request: request, session: session,
	urlResponseValidators: [HTTPStatusCodeURLResponseValidator(expectedCodes: Set(arrayLiteral: 500))],
	resultProcessor: URLToFileHandleResultProcessor().erased,
	retryProviders: [
		NetworkErrorRetryProvider(maximumNumberOfRetries: 1, allowReachabilityObserver: false)
	]
)
operation1.completionBlock = { print("ok1") }
operation2.completionBlock = { print("ok2") }

q.addOperations([operation1, operation2], waitUntilFinished: false)

q.waitUntilAllOperationsAreFinished()
print(operation1.result)
print(operation2.result)

//dispatchMain()
