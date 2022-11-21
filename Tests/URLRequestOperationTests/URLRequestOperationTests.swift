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

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

@testable import URLRequestOperation



@available(tvOS 13.0, iOS 13.0, *)
class URLRequestOperationTests : XCTestCase {
	
	func testRetryCount() {
		class TryCounter : RequestProcessor {
			var count = 0
			func transform(urlRequest: URLRequest, handler: @escaping (Result<URLRequest, Error>) -> Void) {
				count += 1
				handler(.success(urlRequest))
			}
		}
		let counter = TryCounter()
		let op = URLRequestDataOperation.forData(url: URL(string: "https://no.invalid")!, requestProcessors: [counter], retryProviders: [NetworkErrorRetryProvider(maximumNumberOfRetries: 1)])
		op.start()
		op.waitUntilFinished()
		XCTAssertEqual(counter.count, 2)
	}
	
	func testSimpleAPIGet() async throws {
		struct Todo : Decodable {
			var userId: Int
			var id: Int
			var title: String
			var completed: Bool
		}
		let request = URLRequest(url: URL(string: "https://jsonplaceholder.typicode.com/todos/4")!)
		let op = URLRequestDataOperation.forAPIRequest(urlRequest: request, successType: Todo.self)
		do {
			let res = try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<URLRequestOperationResult<Todo>, Error>) in
				op.completionBlock = {
					continuation.resume(with: op.result)
				}
				op.start()
			}
			print(res)
		} catch {
			XCTFail("Got error \(error)")
		}
	}
	
	func testSimpleAPIGetWithParameters() async throws {
		struct Todo : Decodable {
			var userId: Int
			var id: Int
			var title: String
			var completed: Bool
		}
		struct Empty : Decodable {}
		struct Params : Encodable {
			var page: Int
		}
		let op = try URLRequestDataOperation.forAPIRequest(
			url: URL(string: "https://jsonplaceholder.typicode.com")!.appendingPathComponentsSafely("todos"),
			urlParameters: Params(page: 1),
			successType: [Todo].self, errorType: Empty.self
		)
		let res = try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<URLRequestOperationResult<[Todo]>, Error>) in
			op.completionBlock = {
				continuation.resume(with: op.result)
			}
			op.start()
		}
		print(res)
	}
	
	func testSimpleAPIPost() async throws {
		struct Todo : Decodable {
			var userId: Int
			var id: Int
			var title: String
			var completed: Bool
		}
		struct TodoCreation : Encodable {
			var userId: Int
			var title: String
			var completed: Bool
		}
		struct Empty : Decodable {}
		let op = try URLRequestDataOperation.forAPIRequest(
			url: URL(string: "https://jsonplaceholder.typicode.com")!.appendingPathComponentsSafely("todos"), method: "POST",
			httpBody: TodoCreation(userId: 42, title: "I did it!", completed: true),
			successType: Todo.self, errorType: Empty.self
		)
		let res = try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<URLRequestOperationResult<Todo>, Error>) in
			op.completionBlock = {
				continuation.resume(with: op.result)
			}
			op.start()
		}
		print(res)
	}
	
	func testFetchFrostLandStringConstant() async throws {
		let op = URLRequestDataOperation.forString(url: URL(string: "https://frostland.fr/constant.txt")!)
		let res = try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<URLRequestOperationResult<String>, Error>) in
			op.completionBlock = {
				continuation.resume(with: op.result)
			}
			op.start()
		}
		let httpURLResponse = try XCTUnwrap(res.urlResponse as? HTTPURLResponse)
		XCTAssertEqual(httpURLResponse.statusCode, 200)
		XCTAssertEqual(res.result, "42")
	}
	
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
