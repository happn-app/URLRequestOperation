import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import RetryingOperation



public protocol RetryProvider : Sendable {
	
	/**
	 Control how the request is retried in case of an error.
	 
	 In the URLRequestOperation’s flow, if there was an error downloading the data, or when processing the result,
	  the operation will call its retry providers to determine how to retry the operation.
	 
	 The providers are called in order.
	 If a provider tells the request should not be retried (`.some(nil)` is returned), or if it gives some retry helpers,
	  the next providers won’t be called.
	 
	 Must return:
	 - `nil` if the provider does not have a retry helper to retry the request, but the next providers can provide helpers (the request may be retried);
	 - `.some(nil)` if the request must _not_ be retried;
	 - `.some([retryHelpers])` if the provider knows how to retry the operation. */
	func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]??
	
}
