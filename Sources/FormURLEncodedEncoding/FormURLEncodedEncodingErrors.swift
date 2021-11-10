import Foundation



public enum FormURLEncodedEncodingError : Error {
	
	case malformedKey(key: Substring)
	
	case iso8601DateFormatterUnavailable
	
}

typealias Err = FormURLEncodedEncodingError
