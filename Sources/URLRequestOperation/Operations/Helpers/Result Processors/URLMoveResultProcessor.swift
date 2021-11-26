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



public struct URLMoveResultProcessor : ResultProcessor {
	
	public enum MoveBehavior {
		
		/** Throw ``URLRequestOperationError.downloadDestinationExists`` if destination exists. */
		case failIfDestinationExists
		case overwriteDestination
		case findNonExistingFilenameInFolder
		
	}
	
	public typealias SourceType = URL
	public typealias ResultType = URL
	
	public let destinationURL: URL
	public let moveBehavior: MoveBehavior
	
	public let processingQueue: GenericQueue
	
	public let fileManager: FileManager
	
	public init(destinationURL: URL, moveBehavior: MoveBehavior = .failIfDestinationExists, processingQueue: GenericQueue = NoQueue(), fileManager: FileManager = .default) {
		self.destinationURL = destinationURL
		self.moveBehavior = moveBehavior
		
		self.processingQueue = processingQueue
		
		self.fileManager = fileManager
	}
	
	public func transform(source: URL, urlResponse: URLResponse, handler: @escaping (Result<URL, Error>) -> Void) {
		processingQueue.execute{ handler(Result{
			var destinationURL = destinationURL.absoluteURL
			let destinationFolderURL = destinationURL.deletingLastPathComponent()
			
			try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
			
			if fileManager.fileExists(atPath: destinationURL.path) {
				switch moveBehavior {
					case .failIfDestinationExists:
						throw Err.downloadDestinationExists
						
					case .overwriteDestination:
						try fileManager.removeItem(at: destinationURL)
						
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
			
			try fileManager.moveItem(at: source, to: destinationURL)
			return destinationURL
		})}
	}
	
}
