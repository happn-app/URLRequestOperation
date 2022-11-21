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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif



/** Throws ``URLToFileHandleResultProcessorError`` errors. */
public struct URLToFileHandleResultProcessor : ResultProcessor, Sendable {
	
	public typealias SourceType = URL
	public typealias ResultType = FileHandle
	
	public let processingQueue: BlockDispatcher
	
	public init(processingQueue: BlockDispatcher = SyncBlockDispatcher()) {
		self.processingQueue = processingQueue
	}
	
	public func transform(source: URL, urlResponse: URLResponse, handler: @escaping @Sendable (Result<FileHandle, Error>) -> Void) {
		processingQueue.execute{ handler(Result{
			try FileHandle(forReadingFrom: source)
		}.mapError{ MyErr.cannotOpenFile($0) })}
	}
	
}


public enum URLToFileHandleResultProcessorError : Error {
	
	case cannotOpenFile(Error)
	
}

private typealias MyErr = URLToFileHandleResultProcessorError
