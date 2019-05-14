import Foundation

public typealias CodableError = Error & Encodable & Decodable

public struct CodableErrorTypeInfo {
    public var type: CodableError.Type
    public var name: String

    
    public init(type: CodableError.Type,
                name: String? = nil)
    {
        self.type = type
        self.name = name ?? "\(type)"
    }
}
