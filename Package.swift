// swift-tools-version:5.5
import PackageDescription


let package = Package(
	name: "URLRequestOperation",
	products: [
		.library(name: "URLRequestOperation", targets: ["URLRequestOperation"]),
		.library(name: "MediaType", targets: ["MediaType"]),
		.library(name: "FormDataEncoding", targets: ["FormDataEncoding"]),
		.library(name: "FormURLEncodedEncoding", targets: ["FormURLEncodedEncoding"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-collections", from: "1.0.1"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
		.package(url: "https://github.com/Frizlab/stream-reader.git", from: "3.2.3"),
		.package(url: "https://github.com/happn-app/RetryingOperation.git", from: "1.1.6"),
		.package(url: "https://github.com/happn-app/SemiSingleton.git", from: "2.0.3")
	],
	targets: [
		.target(name: "MediaType"),
		.testTarget(name: "MediaTypeTests", dependencies: ["MediaType"]),
		
		.target(name: "FormDataEncoding", dependencies: [
			.product(name: "OrderedCollections", package: "swift-collections"),
			.product(name: "StreamReader",       package: "stream-reader")
		]),
		.testTarget(name: "FormDataEncodingTests", dependencies: ["FormDataEncoding"]),
		
		.target(name: "FormURLEncodedEncoding"),
		.testTarget(name: "FormURLEncodedEncodingTests", dependencies: ["FormURLEncodedEncoding"]),
		
		.target(name: "URLRequestOperation", dependencies: [
			.product(name: "Logging", package: "swift-log"),
			.product(name: "RetryingOperation", package: "RetryingOperation"),
			.product(name: "SemiSingleton", package: "SemiSingleton")
		]),
		.executableTarget(name: "URLRequestOperationManualTest", dependencies: ["URLRequestOperation"]),
		.testTarget(name: "URLRequestOperationTests", dependencies: ["URLRequestOperation"])
	]
)
