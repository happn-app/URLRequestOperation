import Foundation

import RetryingOperation



public protocol RetryProvider {
	
	func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?
	
}
