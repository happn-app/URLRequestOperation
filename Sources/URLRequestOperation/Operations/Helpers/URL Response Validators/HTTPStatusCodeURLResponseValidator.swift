import Foundation



public struct HTTPStatusCodeURLResponseValidator : URLResponseValidator {
	
	public let expectedCodes: Set<Int>
	
	public init(expectedCodes: Set<Int> = Set(200..<300)) {
		self.expectedCodes = expectedCodes
	}
	
	public func validate(urlResponse: URLResponse) -> Error? {
		guard let code = (urlResponse as? HTTPURLResponse)?.statusCode else {
			return Err.unexpectedStatusCode(nil)
		}
		guard expectedCodes.contains(code) else {
			return Err.unexpectedStatusCode(code)
		}
		return nil
	}
	
}
