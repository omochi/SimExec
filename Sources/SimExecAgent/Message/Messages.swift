import Foundation
import FineJSON
import RichJSONParser
import SimExec

public protocol MessageProtocol : Codable {
    static var kind: String { get }
}

public let messageTypes: [MessageProtocol.Type] = [
    RequestErrorResponse.self,
    StateRequest.self,
    StateResponse.self,
    AgentRequestRequest.self,
    AgentRequestStateEvent.self,
    AgentRequestResponse.self
]

extension MessageProtocol {
    public static var kind: String { return "\(self)" }
}

extension MessageProtocol {
    public static func decode(from json: ParsedJSON) throws -> Self {
        let decoder = FineJSONDecoder()
        return try decoder.decode(self, from: json)
    }
    
    public func dispatch_FineJSONEncoder_encodeToJSON(encoder: FineJSONEncoder) throws -> JSON {
        return try encoder.encodeToJSON(self)
    }
}

public protocol RequestMessageProtocol : MessageProtocol {
    var requestID: Int { get }
}

public protocol ResponseMessageProtocol : MessageProtocol {
    var requestID: Int { get }
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
    public func decode(from json: ParsedJSON) throws -> MessageProtocol {
        let decoder = FineJSONDecoder()
        let message = try decoder.decode(MessageDecodeJSON.self, from: json)
        guard let type = (messageTypes.first { $0.kind == message.kind }) else {
            throw MessageError("unknown message kind: \(message.kind)")
        }
        return try type.decode(from: message.body)
    }
}

public final class MessageEncoder {
    public func encode(message: MessageProtocol) throws -> JSON {
        let encoder = FineJSONEncoder()
        let body = try message.dispatch_FineJSONEncoder_encodeToJSON(encoder: encoder)
        let message = MessageEncodeJSON(kind: type(of: message).kind,
                                        body: body)
        return try encoder.encodeToJSON(message)
    }
}

public struct RequestErrorResponse : ResponseMessageProtocol, ErrorBase {
    public var requestID: Int
    public var message: String
    
    public var description: String {
        return message
    }
}

public struct StateRequest : RequestMessageProtocol {
    public var requestID: Int
}

public struct StateResponse : ResponseMessageProtocol {
    public var requestID: Int
    public var state: SimExecAgentTool.State
}

public struct AgentRequestRequest : RequestMessageProtocol {
    public var requestID: Int
    public var request: SimExecAgentTool.Request
}

public struct AgentRequestStateEvent : ResponseMessageProtocol {
    public var requestID: Int
    public var state: SimExecTool.State
}

public struct AgentRequestResponse : ResponseMessageProtocol {
    public var requestID: Int
    public var response: SimExecAgentTool.Response
}


