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



#if os(Linux)

/**
 Unsafe class (not fully tested, not fully documented, slow).
 
 It’s a patch to have the project compile on Linux…
 Do not use outside of the URLRequestOperation project!
 Also the class will leak containers when the key is deallocated as we do not monitor deallocations. */
class LinuxWeakToWeakForGenericURLSessionDelegateMapTable {
	
	func object(forKey key: URLSessionTask) -> URLSessionTaskDelegate? {
		let key = WeakElementBox(e: key)
		guard let w = store[key] else {return nil}
		guard let r = w.element else {
			store.removeValue(forKey: key)
			return nil
		}
		return r
	}
	
	func setObject(_ object: URLSessionTaskDelegate?, forKey key: URLSessionTask) {
		let key = WeakElementBox(e: key)
		guard let o = object else {
			store.removeValue(forKey: key)
			return
		}
		store[key] = WeakDelegateBox(e: o)
	}
	
	
	private class WeakDelegateBox {
		
		weak var element: URLSessionTaskDelegate?
		
		init(e: URLSessionTaskDelegate) {
			element = e
		}
		
	}
	
	private var store = [WeakElementBox<URLSessionTask>: WeakDelegateBox]()
	
}

private class WeakElementBox<ElementType : AnyObject> {
	
	weak var element: ElementType?
	
	init(e: ElementType) {
		element = e
	}
	
}

extension WeakElementBox: Equatable where ElementType: Equatable {
	
	static func ==(lhs: WeakElementBox<ElementType>, rhs: WeakElementBox<ElementType>) -> Bool {
		return lhs.element == rhs.element
	}
	
}

extension WeakElementBox : Hashable where ElementType : Hashable {
	
	func hash(into hasher: inout Hasher) {
		hasher.combine(element)
	}
	
}

#endif
