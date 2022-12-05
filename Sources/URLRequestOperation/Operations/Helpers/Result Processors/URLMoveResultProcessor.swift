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



/* Regarding the "@unchecked" for the Sendability:
 * The compiler cannot guarantee the Sendability of our struct because FileManager is not Sendable.
 * Reading the doc, we learn that using FileManager from multiple threads is ok as long we do not use a delegate, so we should be good. */

/** Throws ``URLMoveResultProcessorError`` errors. */
public struct URLMoveResultProcessor : ResultProcessor, @unchecked Sendable {
	
	public enum MoveBehavior : Sendable {
		
		/** Throw ``URLMoveResultProcessorError/downloadDestinationExists`` if destination exists. */
		case failIfDestinationExists
		case overwriteDestination
		case findNonExistingFilenameInFolder
		
	}
	
	public typealias SourceType = URL
	public typealias ResultType = URL
	
	public let destinationURL: URL
	public let moveBehavior: MoveBehavior
	
	public let processingQueue: BlockDispatcher
	
	public let fileManager: FileManager
	
	public init(destinationURL: URL, moveBehavior: MoveBehavior = .failIfDestinationExists, processingQueue: BlockDispatcher = SyncBlockDispatcher(), fileManager: FileManager = .default) {
		self.destinationURL = destinationURL
		self.moveBehavior = moveBehavior
		
		self.processingQueue = processingQueue
		
		self.fileManager = fileManager
	}
	
	public func transform(source: URL, urlResponse: URLResponse, handler: @escaping @Sendable (Result<URL, Error>) -> Void) {
		processingQueue.execute{ handler(Result{
			var destinationURL = destinationURL.absoluteURL
			let destinationFolderURL = destinationURL.deletingLastPathComponent()
			
			try MyErr.wrapInFileManagerError{ try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil) }
			
			if fileManager.fileExists(atPath: destinationURL.path) {
				switch moveBehavior {
					case .failIfDestinationExists:
						throw MyErr.downloadDestinationExists
						
					case .overwriteDestination:
						try MyErr.wrapInFileManagerError{ try fileManager.removeItem(at: destinationURL) }
						
					case .findNonExistingFilenameInFolder:
						var i = 1
						let ext = destinationURL.pathExtension
						let extWithDot = (ext.isEmpty ? "" : "." + ext)
						let basename = destinationURL.deletingPathExtension().lastPathComponent
						repeat {
							i += 1
							let newBasename = basename + "-" + String(i) + extWithDot
							if #available(macOS 10.11, iOS 9.0, *) {destinationURL = URL(fileURLWithPath: newBasename, isDirectory: false, relativeTo: destinationFolderURL).absoluteURL}
							else                                   {destinationURL = destinationFolderURL.appendingPathComponent(newBasename).absoluteURL}
						} while fileManager.fileExists(atPath: destinationURL.path)
				}
			}
			
			try MyErr.wrapInFileManagerError{ try fileManager.moveItem(at: source, to: destinationURL) }
			return destinationURL
		})}
	}
	
}


public enum URLMoveResultProcessorError : Error {
	
	/** The destination file already exists and the move behavior is ``URLMoveResultProcessor/MoveBehavior-swift.enum/failIfDestinationExists`` */
	case downloadDestinationExists
	
	case fileManagerError(Error)
	
	static func wrapInFileManagerError<T>(_ block: () throws -> T) throws -> T {
		do    {return try block()}
		catch {throw Self.fileManagerError(error)}
	}
	
}

private typealias MyErr = URLMoveResultProcessorError
