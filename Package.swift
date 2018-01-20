// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
		.package(url: "git@github.com:happn-app/AsyncOperationResult", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/RetryingOperation", from: "1.0.0"),
		.package(url: "git@github.com:happn-app/SemiSingleton", from: "1.1.0")
	],
	targets: [
		.target(
			name: "URLRequestOperation",
			dependencies: ["AsyncOperationResult", "RetryingOperation", "SemiSingleton"]
		),
		.testTarget(
			name: "URLRequestOperationTests",
			dependencies: ["URLRequestOperation"]
		)
	]
)
