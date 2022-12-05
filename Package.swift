// swift-tools-version:5.5
import PackageDescription


let swiftSettings: [SwiftSetting] = []
//let swiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]

let package = Package(
	name: "URLRequestOperation",
	products: {
		var ret = [Product]()
		ret.append(.library(name: "MediaType", targets: ["MediaType"]))
		ret.append(.library(name: "URLRequestOperation", targets: ["URLRequestOperation"]))
		return ret
	}(),
	dependencies: {
		var ret = [Package.Dependency]()
		ret.append(.package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"))
		ret.append(.package(url: "https://github.com/happn-app/HTTPCoders.git", from: "0.1.0"))
		ret.append(.package(url: "https://github.com/happn-app/RetryingOperation.git", from: "1.1.6"))
		ret.append(.package(url: "https://github.com/happn-app/SemiSingleton.git", from: "2.1.0-beta.1"))
		return ret
	}(),
	targets: {
		var ret = [Target]()
		ret.append(.target(name: "MediaType", swiftSettings: swiftSettings))
		ret.append(.testTarget(name: "MediaTypeTests", dependencies: ["MediaType"], swiftSettings: swiftSettings))
		
		ret.append(.target(name: "URLRequestOperation", dependencies: {
			var ret = [Target.Dependency]()
			ret.append(.product(name: "FormURLEncodedCoder", package: "HTTPCoders"))
			ret.append(.product(name: "Logging",             package: "swift-log"))
			ret.append(.product(name: "RetryingOperation",   package: "RetryingOperation"))
			ret.append(.product(name: "SemiSingleton",       package: "SemiSingleton"))
			ret.append(.target(name: "MediaType"))
			return ret
		}(), swiftSettings: swiftSettings))
		ret.append(.testTarget(name: "URLRequestOperationTests", dependencies: ["URLRequestOperation"], swiftSettings: swiftSettings))
		ret.append(.executableTarget(name: "URLRequestOperationManualTest", dependencies: ["URLRequestOperation"], swiftSettings: swiftSettings))
		return ret
	}()
)
