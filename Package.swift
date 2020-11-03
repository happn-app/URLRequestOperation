// swift-tools-version:5.1
import PackageDescription


let package = Package(
	name: "URLRequestOperation",
	products: [
		.library(name: "URLRequestOperation", targets: ["URLRequestOperation"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.2.0"),
		.package(url: "https://github.com/happn-tech/AsyncOperationResult.git", from: "1.0.5"),
		.package(url: "https://github.com/happn-tech/RetryingOperation.git", from: "1.1.2"),
		.package(url: "https://github.com/happn-tech/SemiSingleton.git", from: "2.0.3")
	],
	targets: [
		.target(name: "URLRequestOperation", dependencies: [
			.product(name: "AsyncOperationResult", package: "AsyncOperationResult"),
			.product(name: "Logging", package: "swift-log"),
			.product(name: "RetryingOperation", package: "RetryingOperation"),
			.product(name: "SemiSingleton", package: "SemiSingleton")
		]),
		.target(name: "ManualTest", dependencies: ["URLRequestOperation"]),
		.testTarget(name: "URLRequestOperationTests", dependencies: ["URLRequestOperation"])
	]
)
