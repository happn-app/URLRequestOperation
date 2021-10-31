import Foundation



public struct URLToFileHandleResultProcessor : ResultProcessor {
	
	public typealias SourceType = URL
	public typealias ResultType = FileHandle
	
	public init() {
	}
	
	public func transform(source: URL, urlResponse: URLResponse, handler: @escaping (Result<FileHandle, Error>) -> Void) {
		do    {try handler(.success(FileHandle(forReadingFrom: source)))}
		catch {    handler(.failure(error))}
	}
	
}
