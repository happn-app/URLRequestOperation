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

import XCTest
@testable import URLRequestOperation

#if canImport(FoundationNetworking)
	import FoundationNetworking
#endif



class URLRequestOperationTests: XCTestCase {
	
	@available(macOS 12.0.0, *)
	func testSimpleAPIGet() async throws {
		struct Todo : Decodable {
			var userId: Int
			var id: Int
			var title: String
			var completed: Bool
		}
		struct Empty : Decodable {}
		let request = URLRequest(url: URL(string: "https://jsonplaceholder.typicode.com/todos/4")!)
		let op = URLRequestDataOperation<APIResult<Todo, Empty>>.forAPIRequest(urlRequest: request)
		let res = try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<URLRequestOperationResult<APIResult<Todo, Empty>>, Error>) in
			op.completionBlock = {
				continuation.resume(with: op.result)
			}
			op.start()
		}
		print(res)
	}
	
//	func testFetchFrostLandConstant() {
//		let op = URLRequestOperation(url: URL(string: "https://frostland.fr/constant.txt")!)
//		op.start()
//		op.waitUntilFinished()
//		XCTAssertNil(op.finalError)
//		XCTAssertEqual(op.statusCode, 200)
//		XCTAssertEqual(op.fetchedData, Data("42".utf8))
//	}
//
//	func testFetchInvalidHost() {
//		let op = URLRequestOperation(config: URLRequestOperation.Config(request: URLRequest(url: URL(string: "https://invalid.frostland.fr/")!), session: nil, maximumNumberOfRetries: 1))
//		op.start()
//		op.waitUntilFinished()
//		XCTAssertNotNil(op.finalError)
//		XCTAssertNil(op.statusCode)
//	}
//
//	func testFetch404() {
//		let op = URLRequestOperation(url: URL(string: "https://frostland.fr/this_page_does_not_exist.html")!)
//		op.start()
//		op.waitUntilFinished()
//		XCTAssertNotNil(op.finalError)
//		XCTAssertEqual(op.statusCode, 404)
//	}
	
}
