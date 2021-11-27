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

import FormURLEncodedEncoding
import MediaType



extension FormURLEncodedEncoder : HTTPContentEncoder {
	
	public func encode<T>(_ value: T) throws -> (Data, MediaType) where T : Encodable {
		let encodedString: String = try encode(value)
		/* MediaType for form url encoded does not have a charset; content is expected to be UTF-8.
		 * https://stackoverflow.com/a/16829056 */
		return (Data(encodedString.utf8), MediaType(rawValue: "application/x-www-form-urlencoded")!)
	}
	
}
