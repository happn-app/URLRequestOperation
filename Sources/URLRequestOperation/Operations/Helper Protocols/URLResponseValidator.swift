import Foundation



public protocol URLResponseValidator {
	
	/**
	 Method called to validate the URL response.
	 Must return `nil` if the response is ok.
	 
	 A use-case of this validator would be to verify we get a 200 something from the server.
	 
	 The retry providers will still be called if this method returns an error.
	 
	 - Note: The closest API to this one in the data task session delegate is asynchronous
	 (method is `urlSession(:,dataTask:,didReceive:,completionHandler:)`).
	 I do not know why the method is asynchronous.
	 Considering this and the fact we cannot validate responses properly in an asynchronous manner for download tasks,
	 we’ve decided to make this API synchronous. */
	func validate(urlResponse: URLResponse) -> Error?
	
}
