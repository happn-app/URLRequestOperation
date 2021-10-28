import Foundation



public protocol ResultValidator {
	
	func validate(data: Data?, urlResponse: URLResponse, error: Error?) -> Error?
	
}
