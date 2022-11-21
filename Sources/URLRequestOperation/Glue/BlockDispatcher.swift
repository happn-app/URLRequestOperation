/*
Copyright 2021 happn

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

import RetryingOperation



public protocol BlockDispatcher : Sendable {
	
	func execute(_ work: @Sendable @escaping () -> Void)
	
}


public struct SyncBlockDispatcher : BlockDispatcher, Sendable {
	
	public init() {}
	
	public func execute(_ work: @Sendable @escaping () -> Void) {
		work()
	}
	
}


/* @unchecked Sendable: https://forums.swift.org/t/sendable-in-foundation/59577 */
extension OperationQueue : BlockDispatcher, @unchecked Sendable {
	
	public func execute(_ work: @Sendable @escaping () -> Void) {
		addOperation(work)
	}
	
}


/* @unchecked Sendable: https://forums.swift.org/t/capture-of-self-with-non-sendable-closure/55540/6 */
extension DispatchQueue : BlockDispatcher, @unchecked Sendable {
	
	public func execute(_ work: @Sendable @escaping () -> Void) {
		async(execute: work)
	}
	
}
