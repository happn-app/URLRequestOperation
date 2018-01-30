Pod::Spec.new do |spec|
	spec.name = "URLRequestOperation"
	spec.version = "1.0.0"
	spec.summary = "Using OperationQueue for your URL requests (with an built-in retry mechanism)"
	spec.homepage = "https://www.happn.com/"
	spec.license = {type: 'TBD', file: 'License.txt'}
	spec.authors = {"François Lamboley" => 'francois.lamboley@happn.com'}
	spec.social_media_url = "https://twitter.com/happn_tech"

	spec.requires_arc = true
	spec.source = {git: "git@github.com:happn-app/URLRequestOperation.git", tag: spec.version}
	spec.source_files = "Sources/URLRequestOperation/*.swift"
	spec.watchos.exclude_files = "Sources/URLRequestOperation/Reachability*"

	spec.osx.deployment_target = '10.10'
	spec.tvos.deployment_target = '9.0'
	spec.ios.deployment_target = '8.0'
	spec.watchos.deployment_target = '2.0'

	spec.dependency "AsyncOperationResult", "~> 1.0.0"
	spec.dependency "RetryingOperation", "~> 1.0.0"
	spec.dependency "SemiSingleton", "~> 1.1.0"
end
