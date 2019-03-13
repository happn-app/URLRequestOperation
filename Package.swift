// swift-tools-version:4.2

import PackageDescription



let package = Package(
	name: "URLRequestOperation",
	products: [
		.library(
			name: "URLRequestOperation",
			targets: ["URLRequestOperation"]
		)
	],
	dependencies: [
		.package(url: "git@github.com:happn-tech/AsyncOperationResult.git", from: "1.0.5"),
		.package(url: "git@github.com:happn-tech/RetryingOperation.git", from: "1.1.2"),
		.package(url: "git@github.com:happn-tech/DummyLinuxOSLog.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-tech/SemiSingleton.git", from: "2.0.2")
	],
	targets: [
		.target(
			name: "URLRequestOperation",
			dependencies: ["AsyncOperationResult", "RetryingOperation", "SemiSingleton", "DummyLinuxOSLog"]
		),
		.testTarget(
			name: "URLRequestOperationTests",
			dependencies: ["URLRequestOperation"]
		)
	]
)
