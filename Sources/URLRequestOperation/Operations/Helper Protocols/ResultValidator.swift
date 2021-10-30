import Foundation



public protocol ResultValidator {
	
	/**
	 Method called to validate the operation’s result.
	 Must call the handler with `nil` if data/response are ok.
	 
	 This method does not allow you to store intermediate results, like parsed JSON for instance.
	 You should use a ``ResultProcessor`` instead if you need this.
	 Please do not parse the data, then throw it away just to validate the result of the call.
	 (Unless you only need to know you got a valid JSON from your operation, but usually you’ll need the parsed JSON…)
	 
	 The method might be called before any data is received so you can prevent data from being downloaded if the URL response is invalid.
	 It will be called twice if you don’t prevent the data download: once before the data is downloaded and once after.
	 
	 No partial data will ever be given to this method. */
	func validate(data: Data?, urlResponse: URLResponse, error: Error?, handler: @escaping (Error?) -> Void)
	
}
