import Foundation
import RichJSONParser

public protocol MessageProtocol {
    static var kind: String { get }
}

public struct MessageJSON : Codable {
    public var kind: String
    public var body: ParsedJSON
}

public struct StateRequest : Codable {
    public static let kind = "StateRequest"
}
