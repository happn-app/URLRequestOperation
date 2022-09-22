import Foundation



/**
 Simplified HTTP headers struct.
 
 The original FormDataEncoder/FormDataDecoder from Vapor uses NIO’s `HTTPHeaders` struct, but I’d like to avoid pull NIO in this repo. */
public struct HTTPHeaders : Sendable, Equatable, ExpressibleByDictionaryLiteral {
	
	public init(_ headers: [(String, String)] = []) {
		self.headers = headers
	}
	
	public init(dictionaryLiteral elements: (String, String)...) {
		self.init(elements)
	}
	
	/* Adding/removing headers implementation is from NIO 2.33.0 */
	
	/**
	 Add a header name/value pair to the block.
	 
	 This method is strictly additive: if there are other values for the given header name already in the block, this will add a new entry.
	 
	 - Parameter name: The header field name. For maximum compatibility this should be an ASCII string.
	 For future-proofing with HTTP/2 lowercase header names are strongly recommended.
	 - Parameter value: The header field value to add for the given name. */
	public mutating func add(name: String, value: String) {
		precondition(!name.utf8.contains(where: { !$0.isASCII }), "name must be ASCII")
		self.headers.append((name, value))
	}
	
	/**
	 Remove all values for a given header name from the block.
	 
	 This method uses case-insensitive comparisons for the header field name.
	 
	 - Parameter name: The name of the header field to remove from the block. */
	public mutating func remove(name nameToRemove: String) {
		headers.removeAll{ (name, _) in
			/* Note: NIO’s implementation uses a custom function `compareCaseInsensitiveASCIIBytes`, whose implementation is a bit more complex.
			 *       I’m not sure this `==` test is 100% correct, but it is simpler… and should be ok in most cases, if not all. */
			return nameToRemove.lowercased() == name.lowercased()
		}
	}
	
	/**
	 Add a header name/value pair to the block, replacing any previous values for the same header name that are already in the block.
	 
	 This is a supplemental method to `add` that essentially combines `remove` and `add` in a single function.
	 It can be used to ensure that a header block is in a well-defined form without having to check whether the value was previously there.
	 Like `add`, this method performs case-insensitive comparisons of the header field names.
	 
	 - Parameter name: The header field name. For maximum compatibility this should be an ASCII string.
	 For future-proofing with HTTP/2 lowercase header names are strongly recommended.
	 - Parameter value: The header field value to add for the given name. */
	public mutating func replaceOrAdd(name: String, value: String) {
		remove(name: name)
		add(name: name, value: value)
	}
	
	public subscript(name: String) -> [String] {
		return headers.reduce(into: [], { target, lr in
			let (key, value) = lr
			/* Note: NIO’s implementation uses a custom function `compareCaseInsensitiveASCIIBytes`, whose implementation is a bit more complex.
			 *       I’m not sure this `==` test is 100% correct, but it is simpler… and should be ok in most cases, if not all. */
			if key.lowercased() == name.lowercased() {
				target.append(value)
			}
		})
	}
	
	/* Straight from NIO.
	 * I’m not sure why it compares the sorted values instead of just the values, but I trust NIO. */
	public static func ==(lhs: HTTPHeaders, rhs: HTTPHeaders) -> Bool {
		guard lhs.headers.count == rhs.headers.count else {
			return false
		}
		let lhsNames = Set(lhs.names.map{ $0.lowercased() })
		let rhsNames = Set(rhs.names.map{ $0.lowercased() })
		guard lhsNames == rhsNames else {
			return false
		}
		
		for name in lhsNames {
			guard lhs[name].sorted() == rhs[name].sorted() else {
				return false
			}
		}
		
		return true
	}
	
	internal var headers: [(String, String)]
	
	internal var names: [String] {
		 return self.headers.map{ $0.0 }
	}
	
}


/* Straight from NIO’s HTTPHeaders implementation (version 2.33.0). */
extension HTTPHeaders: RandomAccessCollection {
	
	public typealias Element = (name: String, value: String)
	
	public struct Index: Comparable {
		fileprivate let base: Array<(String, String)>.Index
		public static func < (lhs: Index, rhs: Index) -> Bool {
			return lhs.base < rhs.base
		}
	}
	
	public var startIndex: HTTPHeaders.Index {
		return .init(base: self.headers.startIndex)
	}
	
	public var endIndex: HTTPHeaders.Index {
		return .init(base: self.headers.endIndex)
	}
	
	public func index(before i: HTTPHeaders.Index) -> HTTPHeaders.Index {
		return .init(base: self.headers.index(before: i.base))
	}
	
	public func index(after i: HTTPHeaders.Index) -> HTTPHeaders.Index {
		return .init(base: self.headers.index(after: i.base))
	}
	
	public subscript(position: HTTPHeaders.Index) -> Element {
		return self.headers[position.base]
	}
	
}


/* From NIO version 2.33.0 */
private extension UInt8 {
	
	var isASCII: Bool {
		return self <= 127
	}
	
}
