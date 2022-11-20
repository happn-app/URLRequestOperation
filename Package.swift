// swift-tools-version:5.5
import PackageDescription


let swiftSettings: [SwiftSetting] = []
//let swiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]

let package = Package(
	name: "URLRequestOperation",
	products: [
		.library(name: "URLRequestOperation", targets: ["URLRequestOperation"]),
		.library(name: "MediaType", targets: ["MediaType"]),
		.library(name: "FormDataEncoding", targets: ["FormDataEncoding"]),
		.library(name: "FormURLEncodedEncoding", targets: ["FormURLEncodedEncoding"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-collections.git", from: "1.0.1"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
		.package(url: "https://github.com/Frizlab/stream-reader.git", from: "3.2.3"),
		.package(url: "https://github.com/happn-app/RetryingOperation.git", from: "1.1.6"),
		.package(url: "https://github.com/happn-app/SemiSingleton.git", from: "2.1.0-beta.1")
	],
	targets: [
		.target(name: "MediaType", swiftSettings: swiftSettings),
		.testTarget(name: "MediaTypeTests", dependencies: ["MediaType"], swiftSettings: swiftSettings),
		
		.target(name: "FormDataEncoding", dependencies: [
			.product(name: "OrderedCollections", package: "swift-collections"),
			.product(name: "StreamReader",       package: "stream-reader")
		], swiftSettings: swiftSettings),
		.testTarget(name: "FormDataEncodingTests", dependencies: ["FormDataEncoding"], swiftSettings: swiftSettings),
		
		.target(name: "FormURLEncodedEncoding", swiftSettings: swiftSettings),
		.testTarget(name: "FormURLEncodedEncodingTests", dependencies: ["FormURLEncodedEncoding"], swiftSettings: swiftSettings),
		
		.target(name: "URLRequestOperation", dependencies: [
			.product(name: "Logging",           package: "swift-log"),
			.product(name: "RetryingOperation", package: "RetryingOperation"),
			.product(name: "SemiSingleton",     package: "SemiSingleton"),
			.target(name: "FormURLEncodedEncoding"),
			.target(name: "MediaType")
		], swiftSettings: swiftSettings),
		.executableTarget(name: "URLRequestOperationManualTest", dependencies: ["URLRequestOperation"], swiftSettings: swiftSettings),
		.testTarget(name: "URLRequestOperationTests", dependencies: ["URLRequestOperation"], swiftSettings: swiftSettings)
	]
)
