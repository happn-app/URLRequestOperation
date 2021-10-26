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

import URLRequestOperation


class SessionDelegate : NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		print("task ended; error: \(String(describing: error))")
	}
	
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		print("data received")
	}
	
	@available(macOS 10.12, *)
	func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
		print("metrics received")
	}
	
}

/* ************************************************************ */

let session = URLSession(configuration: .ephemeral, delegate: URLRequestOperationSessionDelegateProxy(SessionDelegate()), delegateQueue: nil)
//let t1 = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!)
//let t2 = session.dataTask(with: URL(string: "https://frostland.fr/constant.txt")!, completionHandler: { data, response, error in
//	print("task ended in handler; error \(String(describing: error))")
//})
//
//t1.resume()
//Thread.sleep(forTimeInterval: 1)
//t2.resume()

let q = OperationQueue()
let request = URLRequest(url: URL(string: "https://frostland.fr")!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 0.5)
let operation = URLRequestDataOperation<Data>(request: request, session: session)
operation.completionBlock = { print("ok"); exit(0) }
q.addOperation(operation)

dispatchMain()
