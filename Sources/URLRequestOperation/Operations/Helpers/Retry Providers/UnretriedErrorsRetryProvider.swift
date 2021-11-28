import Foundation

import RetryingOperation



public struct UnretriedErrorsRetryProvider : RetryProvider {
	
	public static func forStatusCodes(_ codes: Set<Int> = Set(400..<500)) -> UnretriedErrorsRetryProvider {
		return Self{ err in
			switch err as? Err {
				case .unexpectedStatusCode(let v, httpBody: nil)?: return v.flatMap{ codes.contains($0) } ?? true
				default:                                           return false
			}
		}
	}
	
	public static func forHTTPContentDecoding() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			if let err = err as? Err {
				switch err {
					case .invalidMediaType:        return true
					case .noOrInvalidContentType:  return true
					case .noDecoderForContentType: return true
					default: (/*nop*/)
				}
			}
			if err is DecodingError {
				return true
			}
			return false
		}
	}
	
	public static func forImageConversion() -> UnretriedErrorsRetryProvider {
		return Self{ err in
			switch err as? Err {
				case .cannotConvertToImage?: return true
				default:                     return false
			}
		}
	}
	
	public let isBlacklistedError: (Error) -> Bool
	
	public init(isBlacklistedError: @escaping (Error) -> Bool) {
		self.isBlacklistedError = isBlacklistedError
	}
	
	public func retryHelpers(for request: URLRequest, error: Error, operation: URLRequestOperation) -> [RetryHelper]?? {
		if isBlacklistedError(error) {
			return .some(nil)
		}
		return nil
	}
	
}
