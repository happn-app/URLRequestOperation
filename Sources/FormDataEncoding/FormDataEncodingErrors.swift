import Foundation



public enum FormDataEncodingError : Sendable, Error {
	
	case cannotWriteToStream(Error?)
	case syntaxErrorInSerializedMultipart
	
	case internalError
	
}

typealias Err = FormDataEncodingError
