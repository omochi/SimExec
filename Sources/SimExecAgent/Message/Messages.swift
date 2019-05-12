import Foundation
import FineJSON
import RichJSONParser
import SimExec

public protocol MessageProtocol : Codable {
    static var kind: String { get }
}

extension MessageProtocol {
    public static var kind: String { return "\(self)" }
}

extension MessageProtocol {
    public static func decode(from json: ParsedJSON) throws -> Self {
        let decoder = FineJSONDecoder()
        return try decoder.decode(self, from: json)
    }
}

private struct MessageDecodeJSON : Decodable {
    public var kind: String
    public var body: ParsedJSON
}

private struct MessageEncodeJSON : Encodable {
    public var kind: String
    public var body: JSON
}

public final class MessageDecoder {
    public var types: [MessageProtocol.Type] = [
        StateRequest.self
    ]
    
    public func decode(from json: ParsedJSON) throws -> MessageProtocol {
        let decoder = FineJSONDecoder()
        let message = try decoder.decode(MessageDecodeJSON.self, from: json)
        guard let type = (types.first { $0.kind == message.kind }) else {
            throw MessageError("unknown message kind: \(message.kind)")
        }
        return try type.decode(from: message.body)
    }
}

public final class MessageEncoder {
    public func encode<T: MessageProtocol>(message: T) throws -> JSON {
        let encoder = FineJSONEncoder()
        let body = try encoder.encodeToJSON(message)
        let message = MessageEncodeJSON(kind: type(of: message).kind,
                                        body: body)
        return try encoder.encodeToJSON(message)
    }
}

public struct StateRequest : MessageProtocol {
    public var requestID: Int
}

public struct StateResponse : MessageProtocol {
    public var requestID: Int
    public var satte: SimExecAgentTool.State
}
