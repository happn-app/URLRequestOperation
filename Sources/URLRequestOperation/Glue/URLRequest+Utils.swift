/*
Copyright 2022 happn

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
#if canImport(os)
import os.log
#endif



extension URLRequest {
	
	func logIfNeeded(operationID: URLRequestOperationID) {
		guard let maxSize = Conf.maxRequestBodySizeToLog else {
			return
		}
		
		let (bodyStrPrefix, bodyTransform, bodyStr): (String, String?, String?) = httpBody.flatMap{ httpBody in
			if httpBody.count <= maxSize {
				if let str = String(data: httpBody, encoding: .utf8) {
					return ("Quoted body: ", "to-str", str) /* Quoted later. */
				} else {
					return ("Hex-encoded body: ", "to-hex", httpBody.reduce("0x", { $0 + String(format: "%02x", $1) }))
				}
			} else {
				return ("Body skipped (too big)", nil, nil)
			}
		} ?? ("No body", "to-str", "")
#if canImport(os)
		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			Conf.oslog.flatMap{ os_log(
				"""
				URLOpID %{public}@: Starting request.
				   URL: %@
				   Method: %{public}@
				   Body size: %{private}ld
				   %{public}@%@
				""",
				log: $0,
				type: .debug,
				String(describing: operationID),
				url?.absoluteString ?? "<nil>",
				httpMethod ?? "<nil>",
				httpBody?.count ?? 0,
				bodyStrPrefix, (bodyStr ?? "").quoted(emptyStaysEmpty: true)
			) }}
#endif
		Conf.logger?.trace("Starting a new request.", metadata: [
			LMK.operationID: "\(operationID)",
			LMK.requestURL: "\(url?.absoluteString ?? "<None>")",
			LMK.requestMethod: "\(httpMethod ?? "<None>")",
			LMK.requestBody: bodyStr.flatMap{ "\($0)" },
			LMK.requestBodySize: "\(httpBody?.count ?? 0)",
			LMK.requestBodyTransform: bodyTransform.flatMap{ "\($0)" }
		].compactMapValues{ $0 })
	}
	
}
