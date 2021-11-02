import Foundation



public protocol URLResponseValidator {
	
	/**
	 Method called to validate the URL response.
	 Must return `nil` if the response is ok.
	 
	 A use-case of this validator would be to verify we get a 200 something from the server.
	 
	 The retry providers will still be called if this method returns an error.
	 
	 - Note: The closest API to this one in the data task session delegate is asynchronous
	 (method is `urlSession(:,dataTask:,didReceive:,completionHandler:)`).
	 
	 The asynchronicity allows the dev to let the user choose whether he allows downloading a file, if
	 the response indicates the data task should be transformed to a download task for instance
	 ([see this Developer Forums post](https://developer.apple.com/forums/thread/693645?answerId=693559022#693559022)).
	 
	 URLRequestOperation’s goal is not to replace URLSession’s delegate.
	 If you need to convert your task to a download task, or need to be async in general when validating the response,
	 you should use the session’s delegate. */
	func validate(urlResponse: URLResponse) -> Error?
	
}
