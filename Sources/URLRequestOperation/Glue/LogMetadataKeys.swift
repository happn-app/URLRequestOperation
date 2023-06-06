import Foundation



public enum LoggerMetadataKeys {
	
	public static let operationID: String = "url_request_operation_id"
	
	public static let requestURL: String = "request_url"
	public static let requestMethod: String = "request_method"
	public static let requestBody: String = "request_body"
	public static let requestBodySize: String = "request_body_size"
	public static let requestBodyTransform: String = "request_body_transform"
	
	public static let responseHTTPCode: String = "response_http_code"
	public static let responseData: String = "response_data"
	public static let responseDataSize: String = "response_data_size"
	public static let responseDataTransform: String = "response_data_type"
	
}

typealias LMK = LoggerMetadataKeys
