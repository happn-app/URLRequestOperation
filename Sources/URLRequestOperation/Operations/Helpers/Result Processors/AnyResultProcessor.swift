import Foundation




public extension ResultProcessor {
	
	var erased: AnyResultProcessor<SourceType, ResultType> {
		return .init(self)
	}
	
}


public struct AnyResultProcessor<SourceType, ResultType> : ResultProcessor {
	
	public static func identity<T>() -> AnyResultProcessor<T, T> {
		return AnyResultProcessor<T, T>(transformHandler: { s, _, h in h(.success(s)) })
	}
	
	public init<RP : ResultProcessor>(_ p: RP) where RP.SourceType == Self.SourceType, RP.ResultType == Self.ResultType {
		self.transformHandler = p.transform
	}
	
	public init(transformHandler: @escaping (SourceType, URLResponse, @escaping (Result<ResultType, Error>) -> Void) -> Void) {
		self.transformHandler = transformHandler
	}
	
	public func transform(source: SourceType, urlResponse: URLResponse, handler: @escaping (Result<ResultType, Error>) -> Void) {
		transformHandler(source, urlResponse, handler)
	}
	
	private let transformHandler: (SourceType, URLResponse, @escaping (Result<ResultType, Error>) -> Void) -> Void
	
}
