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
		.package(url: "git@github.com:happn-app/AsyncOperationResult.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/RetryingOperation.git", from: "1.1.1"),
		.package(url: "git@github.com:happn-app/DummyLinuxOSLog.git", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/SemiSingleton.git", from: "2.0.0")
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
