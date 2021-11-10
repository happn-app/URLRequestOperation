import Foundation



public enum FormDataEncodingError : Error {
	
	case cannotWriteToStream(Error?)
	case syntaxErrorInSerializedMultipart
	
	case internalError
	
}

typealias Err = FormDataEncodingError
