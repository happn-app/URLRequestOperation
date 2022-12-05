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

import FormURLEncodedCoder



extension URL {
	
	internal func appendingQueryParameters<Parameters : Encodable>(from parameters: Parameters, encoder: URLQueryEncoder = Conf.defaultAPIRequestParametersEncoder) throws -> URL {
#warning("TODO: Modify the URLQueryEncoder to encode to an array of URLQueryItem instead of a String and use this array to add the query parameters. This will allow using appending(queryItems:) for iOS 16+ and co, or URLComponents for iOS 15-.")
		let encoded: String = try encoder.encode(parameters)
		/* We do the URL/URLComponents trip, because otherwise it’s annoying to manage the fragment.
		 * If the fragment were not there, I’d have simply appended the encoded parameters to the URL, w/ a “?” or a “&” before depending on whether query is nil. */
		guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
			throw Err.failedConversionBetweenURLAndURLComponents
		}
		components.percentEncodedQuery = (components.percentEncodedQuery.flatMap{ $0 + "&" } ?? "") + encoded
		guard let ret = components.url else {
			throw Err.failedConversionBetweenURLAndURLComponents
		}
		return ret
	}
	
	public func appendingQueryParameters<Parameters : Encodable>(from parameters: Parameters?, encoder: URLQueryEncoder = URLRequestOperationConfig.defaultAPIRequestParametersEncoder) throws -> URL {
		guard let parameters = parameters else {
			return self
		}
		return try appendingQueryParameters(from: parameters, encoder: encoder)
	}
	
	/**
	 Does **not** check whether the components contain a `/` (like URL’s `appendingPathComponent`).
	 
	 - Note: Deprecation tells to use the new `appending(components:directoryHint:)` method, but it’s not the same.
	 The new method is indeed **much** better as it percent-encode the `/` in the components… */
	@available(iOS, deprecated: 16.0, message: "Use Foundation’s appending(components:directoryHint:).")
	@available(tvOS, deprecated: 16.0, message: "Use Foundation’s appending(components:directoryHint:).")
	@available(macOS, deprecated: 13.0, message: "Use Foundation’s appending(components:directoryHint:).")
	@available(watchOS, deprecated: 9.0, message: "Use Foundation’s appending(components:directoryHint:).")
	public func appendingPathComponents(_ components: String...) -> URL {
		return components.reduce(self, { reduced, new in reduced.appendingPathComponent(new) })
	}
	
	/**
	 Shorter name for ``appendingPathComponentsSafely(_:)``.
	 
	 - Note: Deprecation tells to use the new `appending(components:directoryHint:)` method, but it’s not the same.
	 The new Foundation method percent-encode the `/` in the path components; this method throws if any component contains a `/`. */
	@available(iOS, deprecated: 16.0, message: "Use Foundation’s version.")
	@available(tvOS, deprecated: 16.0, message: "Use Foundation’s version.")
	@available(macOS, deprecated: 13.0, message: "Use Foundation’s version.")
	@available(watchOS, deprecated: 9.0, message: "Use Foundation’s version.")
	public func appending(_ components: String...) throws -> URL {
		try appendingPathComponentsSafely(components)
	}
	
	/**
	 Throws if any of the given component contains a path separator.
	 
	 - Note: Deprecation tells to use the new `appending(components:directoryHint:)` method, but it’s not the same.
	 The new Foundation method percent-encode the `/` in the path components; this method throws if any component contains a `/`. */
	@available(iOS, deprecated: 16.0, message: "Use Foundation’s version.")
	@available(tvOS, deprecated: 16.0, message: "Use Foundation’s version.")
	@available(macOS, deprecated: 13.0, message: "Use Foundation’s version.")
	@available(watchOS, deprecated: 9.0, message: "Use Foundation’s version.")
	public func appendingPathComponentsSafely(_ components: String...) throws -> URL {
		try appendingPathComponentsSafely(components)
	}
	
	/**
	 Non-variadic variant of ``appendingPathComponentsSafely(_:)``.
	 
	 - Note: Deprecation tells to use the new `appending(components:directoryHint:)` method, but it’s not the same.
	 The new Foundation method percent-encode the `/` in the path components; this method throws if any component contains a `/`. */
	@available(iOS, deprecated: 16.0, message: "Use Foundation’s version.")
	@available(tvOS, deprecated: 16.0, message: "Use Foundation’s version.")
	@available(macOS, deprecated: 13.0, message: "Use Foundation’s version.")
	@available(watchOS, deprecated: 9.0, message: "Use Foundation’s version.")
	public func appendingPathComponentsSafely(_ components: [String]) throws -> URL {
		/* Let’s check the given path is valid (does not contain a path separator).
		 * Note: We hardcode the path separator for now, but we shouldn’t. */
		if let invalid = components.first(where: { $0.range(of: "/") != nil }) {
			throw Err.invalidPathComponent(invalid)
		}
		return components.reduce(self, { reduced, new in reduced.appendingPathComponent(new) })
	}
	
}
