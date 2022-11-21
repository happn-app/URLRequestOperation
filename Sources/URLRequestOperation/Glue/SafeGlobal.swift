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



/* We use the same lock for all SafeGlobal instances.
 * We could use one lock per instance instead but there’s no need AFAICT. */
private let safeGlobalLock = NSLock()

@propertyWrapper
public class SafeGlobal<T : Sendable> : @unchecked Sendable {
	
	public var wrappedValue: T {
		get {safeGlobalLock.withLock{ _wrappedValue }}
		set {safeGlobalLock.withLock{ _wrappedValue = newValue }}
	}
	
	public init(wrappedValue: T) {
		self._wrappedValue = wrappedValue
	}
	
	private var _wrappedValue: T
	
}
