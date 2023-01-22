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

import RetryingOperation

@testable import URLRequestOperation



@available(tvOS 13.0, iOS 13.0, *)
class URLRequestOperationTests : XCTestCase {
	
	override class func setUp() {
		URLRequestOperationConfig.maxRequestBodySizeToLog = .max
		URLRequestOperationConfig.maxResponseBodySizeToLog = .max
	}
	
	func testRetryCount() {
		final class TryCounter : RequestProcessor, @unchecked Sendable {
			var _count = 0
			var lock = NSLock()
			var count: Int {lock.withLock{ _count }}
			func transform(urlRequest: URLRequest, handler: @escaping (Result<URLRequest, Error>) -> Void) {
				lock.withLock{ _count += 1 }
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
		struct Todo : Decodable, Equatable {
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
			XCTAssertEqual(res.result, Todo(userId: 1, id: 4, title: "et porro tempora", completed: true))
		} catch {
			XCTFail("Got error \(error)")
		}
	}
	
	func testSimpleAPIGetWithParameters() async throws {
		struct Todo : Decodable, Equatable {
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
		XCTAssertGreaterThan(res.result.count, 1)
		XCTAssertEqual(res.result.first, Todo(userId: 1, id: 1, title: "delectus aut autem", completed: false))
	}
	
	func testSimpleAPIPost() async throws {
		struct Todo : Decodable, Equatable {
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
		XCTAssertEqual(res.result, Todo(userId: 42, id: 201, title: "I did it!", completed: true))
	}
	
	func testFetchFrostLandStringConstant() async throws {
		let url = URL(string: "https://frostland.fr/constant.txt")!
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
		let op = URLRequestDataOperation.forString(urlRequest: request)
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
	
	func testFetchInvalidHost() {
		let op = URLRequestDataOperation.forData(url: URL(string: "https://invalid.frostland.fr/")!, retryProviders: [NetworkErrorRetryProvider(maximumNumberOfRetries: 1)])
		op.start()
		op.waitUntilFinished()
		XCTAssertNotNil(op.result.failure)
	}
	
	func testFetch404() {
		let op = URLRequestDataOperation.forData(url: URL(string: "https://frostland.fr/this_page_does_not_exist.html")!)
		op.start()
		op.waitUntilFinished()
		XCTAssertNotNil(op.result.failure)
		XCTAssertEqual(op.result.failure?.unexpectedStatusCodeError?.actual, 404)
	}
	
	func testCancellationBeforeRun() {
		let op = URLRequestDataOperation.forString(url: URL(string: "https://frostland.fr/constant.txt")!)
		op.cancel()
		op.start()
		op.waitUntilFinished()
		XCTAssertEqual(op.result.failure?.isCancelledError, true)
	}
	
	func testCancellationDuringRetry() async throws {
		struct RetryNever : RetryProvider, RetryHelper {
			func retryHelpers(for request: URLRequest, error: URLRequestOperationError, operation: URLRequestOperation) -> [RetryHelper]?? {
				return [self]
			}
			func setup() {}
			func teardown() {}
		}
		let op = URLRequestDataOperation.forString(url: URL(string: "https://invalid.frostland.fr/")!, retryProviders: [RetryNever()])
		Task{
			try await Task.sleep(nanoseconds: 5_000_000_000)
			op.cancel()
		}
		var err: Error?
		do {
			_ = try await withCheckedThrowingContinuation{ (continuation: CheckedContinuation<URLRequestOperationResult<String>, Error>) in
				op.completionBlock = {
					continuation.resume(with: op.result)
				}
				op.start()
			}
		} catch {
			err = error
		}
		XCTAssertEqual((err as? URLRequestOperationError)?.isCancelledError, true)
	}
	
	func testFailedRetry() {
		struct RetryError : Error {}
		struct RetryFailProvider : RetryProvider {
			struct RetryFail : RetryHelper {
				let op: URLRequestOperation
				func setup() {
					op.retryError = RetryError()
					op.retryNow()
				}
				func teardown() {}
			}
			func retryHelpers(for request: URLRequest, error: URLRequestOperationError, operation: URLRequestOperation) -> [RetryHelper]?? {
				guard error.retryError == nil else {return .some(nil)}
				return [RetryFail(op: operation)]
			}
		}
		let op = URLRequestDataOperation.forString(url: URL(string: "https://invalid.frostland.fr/")!, retryProviders: [RetryFailProvider()])
		op.start()
		op.waitUntilFinished()
		XCTAssertNotNil(op.result.failure?.retryError)
	}
	
}
