// swift-tools-version:5.5
import PackageDescription


let swiftSettings: [SwiftSetting] = []
//let swiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]

let package = Package(
	name: "URLRequestOperation",
	products: buildArray{
		$0.append(.library(name: "MediaType", targets: ["MediaType"]))
		$0.append(.library(name: "URLRequestOperation", targets: ["URLRequestOperation"]))
	},
	dependencies: buildArray{
		$0.append(.package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"))
		$0.append(.package(url: "https://github.com/happn-app/HTTPCoders.git", from: "0.1.0"))
		$0.append(.package(url: "https://github.com/happn-app/RetryingOperation.git", from: "1.1.6"))
		$0.append(.package(url: "https://github.com/happn-app/SemiSingleton.git", from: "2.1.0-beta.1"))
	},
	targets: buildArray{
		$0.append(.target(name: "MediaType", swiftSettings: swiftSettings))
		$0.append(.testTarget(name: "MediaTypeTests", dependencies: ["MediaType"], swiftSettings: swiftSettings))
		
		$0.append(.target(name: "URLRequestOperation", dependencies: buildArray{
			$0.append(.product(name: "FormURLEncodedCoder", package: "HTTPCoders"))
			$0.append(.product(name: "Logging",             package: "swift-log"))
			$0.append(.product(name: "RetryingOperation",   package: "RetryingOperation"))
			$0.append(.product(name: "SemiSingleton",       package: "SemiSingleton"))
			$0.append(.target(name: "MediaType"))
		}, swiftSettings: swiftSettings))
		$0.append(.testTarget(name: "URLRequestOperationTests", dependencies: ["URLRequestOperation"], swiftSettings: swiftSettings))
		$0.append(.executableTarget(name: "URLRequestOperationManualTest", dependencies: ["URLRequestOperation"], swiftSettings: swiftSettings))
	}
)


func buildArray<Element>(of type: Any.Type = Element.self, _ builder: (_ collection: inout [Element]) -> Void) -> [Element] {
	var ret = [Element]()
	builder(&ret)
	return ret
}
