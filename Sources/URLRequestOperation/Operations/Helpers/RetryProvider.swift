import Foundation

import RetryingOperation



public protocol RetryProvider {
	
	func retryHelpers(for error: Error) -> [RetryHelper]?
	
}
