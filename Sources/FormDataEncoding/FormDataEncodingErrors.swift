import Foundation



public enum FormDataEncodingError : Error {
	
	case cannotWriteToStream(Error?)
	
	case internalError
	
}

typealias Err = FormDataEncodingError
