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
#if canImport(OSLog)
import OSLog
#endif

import Logging

import FormURLEncodedEncoding



/**
 The global configuration for RetryingOperation.
 
 You can modify all of the variables in this struct to change the default behavior of RetryingOperation.
 Be careful, none of these properties are thread-safe.
 It is a good practice to change the behaviors you want when you start your app, and then leave the config alone.
 
 - Note: We allow the configuration for a generic `Logger` (from Apple’s swift-log repository), **and** an `OSLog` logger.
 We do this because Apple recommends using `OSLog` directly whenever possible for performance and privacy reason
  (see [swift-log’s Readme](https://github.com/apple/swift-log/blob/4f876718737f2c2b2ecd6d4cb4b99e0367b257a4/README.md) for more informations).
 
 The recommended configuration for Logging is to use `OSLog` when you can (you are on an Apple platform that supports `OSLog`) and `Logger` otherwise.
 You can also configure both if you want, though I’m not sure why that would be needed.
 
 In the future, OSLog’s API should be modified to match the swift-log’s one, and we’ll then probably drop the support for OSLog
  (because you’ll be able to use OSLog through Logging without any performance or privacy hit). */
public enum URLRequestOperationConfig {
	
#if canImport(os)
	@available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *)
	public static let oslog: OSLog? = .default
	/* This retricts availability of Apple’s logging, so we keep the OSLog variant for now, even if it is less convenient. */
//	@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
//	public static var oslog: os.Logger? = .init(.default)
#endif
	public static let logger: Logging.Logger? = {
#if canImport(os)
		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			return nil
		}
#endif
		return Logger(label: "com.happn.URLRequestOperation")
	}()
	
	public static var defaultAPIResponseDecoders: [HTTPContentDecoder] = [JSONDecoder()]
	public static var defaultAPIRequestBodyEncoder: HTTPContentEncoder = JSONEncoder()
	public static var defaultAPIRequestParametersEncoder: URLQueryEncoder = FormURLEncodedEncoder()
	/** Before these retry providers, there will always be retry providers to block content decoding or unexpected status code errors. */
	public static var defaultAPIRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	public static var defaultAPIRetryableStatusCodes: Set<Int> = [503]
	
	/** Before these retry providers, there will always be retry providers to block unexpected status code errors. */
	public static var defaultDataRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	public static var defaultDataRetryableStatusCodes: Set<Int> = [503]
	
	/** Before these retry providers, there will always be retry providers to block image conversion failure or unexpected status code errors. */
	public static var defaultImageRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	public static var defaultImageRetryableStatusCodes: Set<Int> = [503]
	
	public static var defaultStringEncoding: String.Encoding = .utf8
	/** Before these retry providers, there will always be retry providers to block string conversion failure or unexpected status code errors. */
	public static var defaultStringRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	public static var defaultStringRetryableStatusCodes: Set<Int> = [503]
	
	/** Before these retry providers, there will always be retry providers to block download specific error or unexpected status code errors. */
	public static var defaultDownloadRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	public static var defaultDownloadRetryableStatusCodes: Set<Int> = [503]
	
	public static var networkRetryProviderDefaultNumberOfRetries: Int? = 7
	public static var networkRetryProviderBackoffTable: [TimeInterval] = [1, 3, 15, 27, 42, 60, 60 * 60, 6 * 60 * 60]
	
	/**
	 When data has been fetched from a server, if it is a valid UTF-8 string, should we log it?
	 Set to true for debug purpose. */
	public static var logFetchedStrings = false
	/** Log everything URL Session related in the file at the given URL. */
	public static var debugLogURL: URL?
	
}

typealias Conf = URLRequestOperationConfig
