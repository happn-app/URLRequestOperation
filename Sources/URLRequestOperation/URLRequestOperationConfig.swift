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
@preconcurrency import OSLog
#endif

import Logging

import FormURLEncodedCoder



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
	@SafeGlobal public static var oslog: OSLog? = .default
	/* This retricts availability of Apple’s logging, so we keep the OSLog variant for now, even if it is less convenient. */
//	@available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *)
//	public static var oslog: os.Logger? = .init(.default)
#endif
	@SafeGlobal public static var logger: Logging.Logger? = {
#if canImport(os)
		if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
			return nil
		}
#endif
		return Logger(label: "com.happn.URLRequestOperation")
	}()
	
	/* Maybe TODO: Avoid locking each and every time we access the conf variable.
	 * The global idea is to use
	 *    let myConfVar: MyType = { return myValue }()
	 *
	 * This is thread-safe!
	 *
	 * So there’s probably a lock from the language, but it’s probably(?) better than an NSLock…
	 *  … and it’s more in the philosophy of the configuration the way I see it:
	 *  once the config is accessed once, it should not change.
	 *
	 * A full implementation could look like this (untested; probable good candidate for a macro):
	 *
	 *    /* We use the same lock for all Conf instances.
	 *     * We could use one lock per instance instead but there’s no need AFAICT. */
	 *    private let confLock = NSLock()
	 *    @propertyWrapper public class Conf<T : Sendable> : @unchecked Sendable {
	 *    	var hasBeenAccessed = false
	 *    	public var wrappedValue: T {
	 *    		/* If needed, we could have an explicit method to access the wrapped value and set hasBeenAccessed
	 *    		 *  (I’m worried the variable would get accessed for some reasons, outside of the _myVar init block). */
	 *    		get {safeGlobalLock.withLock{ hasBeenAccessed = true; _wrappedValue }}
	 *    		set {safeGlobalLock.withLock{ assert(!hasBeenAccessed, "A conf variable cannot be changed after having been accessed."); _wrappedValue = newValue }}
	 *    	}
	 *    	public init(wrappedValue: T) {
	 *    		self._wrappedValue = wrappedValue
	 *    	}
	 *    	private var _wrappedValue: T
	 *    }
	 *    /* The conf entity used externally to set conf values. */
	 *    public enum ServiceConf {
	 *    	@Conf public static var myVar: MyType = defaultValue
	 *    }
	 *    /* The conf entity used to access configuration internally. */
	 *    internal enum Conf {
	 *    	internal static let myVar = { ServiceConf.myVar }()
	 *    }
	 */
	
	@SafeGlobal public static var defaultAPIResponseDecoders: [HTTPContentDecoder] = [SendableJSONDecoderForHTTPContent()]
	@SafeGlobal public static var defaultAPIRequestBodyEncoder: HTTPContentEncoder = SendableJSONEncoderForHTTPContent()
	@SafeGlobal public static var defaultAPIRequestParametersEncoder: URLQueryEncoder = FormURLEncodedEncoder()
	/** Before these retry providers, there will always be retry providers to block content decoding or unexpected status code errors. */
	@SafeGlobal public static var defaultAPIRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	@SafeGlobal public static var defaultAPIRetryableStatusCodes: Set<Int> = [503]
	
	/** Before these retry providers, there will always be retry providers to block unexpected status code errors. */
	@SafeGlobal public static var defaultDataRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	@SafeGlobal public static var defaultDataRetryableStatusCodes: Set<Int> = [503]
	
	/** Before these retry providers, there will always be retry providers to block image conversion failure or unexpected status code errors. */
	@SafeGlobal public static var defaultImageRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	@SafeGlobal public static var defaultImageRetryableStatusCodes: Set<Int> = [503]
	
	@SafeGlobal public static var defaultStringEncoding: String.Encoding = .utf8
	/** Before these retry providers, there will always be retry providers to block string conversion failure or unexpected status code errors. */
	@SafeGlobal public static var defaultStringRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	@SafeGlobal public static var defaultStringRetryableStatusCodes: Set<Int> = [503]
	
	/** Before these retry providers, there will always be retry providers to block download specific error or unexpected status code errors. */
	@SafeGlobal public static var defaultDownloadRetryProviders: [RetryProvider] = [NetworkErrorRetryProvider()]
	@SafeGlobal public static var defaultDownloadRetryableStatusCodes: Set<Int> = [503]
	
	@SafeGlobal public static var networkRetryProviderDefaultNumberOfRetries: Int? = 7
	@SafeGlobal public static var networkRetryProviderBackoffTable: [TimeInterval] = [1, 3, 15, 27, 42, 60, 60 * 60, 6 * 60 * 60] as [TimeInterval]
	
	/**
	 When sending data to a server, should we log it?
	 
	 `URLRequestOperation` can log all the requests that are started at log level trace.
	 This variable controls when the requests should be logged depending on the request’s body size.
	 
	 If variable is set to `nil`, requests are never logged.
	 Unless in debug mode, you should leaving it `nil`.
	 
	 If non-`nil`, all requests are logged, and the body is logged only if its size is lower than the value.
	 For requests whose body is bigger than the value, the body size is printed instead of the body.
	 
	 Set the value to `.max` to log _everything_.
	 This is dangerous though as you can get very big logs depending on your usage. */
	@SafeGlobal public static var maxRequestBodySizeToLog: Int? = nil
	/**
	 When receiving data from a server, should we log it?
	 
	 `URLRequestOperation` can log all the responses that are received at log level trace.
	 This variable controls when the responses should be logged depending on the response’s data size.
	 
	 If variable is set to `nil`, responses are never logged.
	 Unless in debug mode, you should leaving it `nil`.
	 
	 If non-`nil`, all responses are logged, and the body is logged only if its size is lower than the value.
	 For responses whose body is bigger than the value, the body size is printed instead of the body.
	 
	 Set the value to `.max` to log _everything_.
	 This is dangerous though as you can get very big logs depending on your usage. */
	@SafeGlobal public static var maxResponseBodySizeToLog: Int? = nil
	/** Log everything URL Session related in the file at the given URL. */
//	@SafeGlobal public static var debugLogURL: URL?
	
}

typealias Conf = URLRequestOperationConfig
