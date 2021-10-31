import Foundation



public protocol URLResponseValidator {
	
	/**
	 Method called to validate the URL response.
	 Must call the handler with `nil` if the response is ok.
	 
	 A use-case of this validator would be to verify we get a 200 something from the server.
	 
	 The retry providers will still be called if this method returns an error. */
	func validate(urlResponse: URLResponse, handler: @escaping (Error?) -> Void)
	
}
