import Foundation

public struct MessageError : ErrorBase, Codable {
    public var message: String
    
    public init(_ message: String) {
        self.message = message
    }
    
    public var description: String {
        return message
    }
}
