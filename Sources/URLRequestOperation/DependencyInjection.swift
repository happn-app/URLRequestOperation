/*
 * DependencyInjection.swift
 * URLRequestOperation
 *
 * Created by François Lamboley on 1/13/18.
 * Copyright © 2018 happn. All rights reserved.
 */

import Foundation
#if canImport(os)
	import os.log
#endif

#if canImport(DummyLinuxOSLog)
	import DummyLinuxOSLog
#endif



public struct DependencyInjection {
	
	init() {
		debugLogURL = nil
		logFetchedStrings = false
		if #available(OSX 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {log = .default}
		else                                                          {log = nil}
	}
	
	public var log: OSLog?
	
	/** When data has been fetched from a server, if it is a valid UTF-8 string,
	should we log it? Set to true for debug purpose. */
	public var logFetchedStrings: Bool
	/** Log everything URL Session related in the given URL. */
	public var debugLogURL: URL?
	
}

public var di = DependencyInjection()
