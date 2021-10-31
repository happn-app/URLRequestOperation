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
	
	public let fileManager: FileManager
	
	public init(destinationURL: URL, moveBehavior: MoveBehavior = .failIfDestinationExists, fileManager: FileManager = .default) {
		self.destinationURL = destinationURL
		self.moveBehavior = moveBehavior
		
		self.fileManager = fileManager
	}
	
	public func transform(source: URL, urlResponse: URLResponse, handler: @escaping (Result<URL, Error>) -> Void) {
		do {
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
			handler(.success(destinationURL))
		} catch {
			handler(.failure(error))
		}
	}
	
}
