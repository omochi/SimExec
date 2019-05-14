import Foundation
import FineJSON
import RichJSONParser
import SimExec

public protocol MessageProtocol : Codable {
    static var name: String { get }
}

public let messageTypes: [MessageProtocol.Type] = [
    AgentStateEvent.self,
    AgentRequestRequest.self,
    AgentRequestResponse.self
]

extension MessageProtocol {
    public static var name: String { return "\(self)" }
}

extension MessageProtocol {
    public func dispatch_KeyedEncodingContainer_encode<K>(
        container: inout KeyedEncodingContainer<K>,
        forKey key: K) throws
        where K : CodingKey
    {
        try container.encode(self, forKey: key)
    }
}

public struct AgentStateEvent : MessageProtocol {
    public var state: SimExecAgentTool.State
}

public struct AgentRequestRequest : MessageProtocol {
    public var request: SimExecAgentTool.Request
}

public struct AgentRequestResponse : MessageProtocol {
    public var result: Result<SimExecAgentTool.Response, Error>
    
    public init(result: Result<SimExecAgentTool.Response, Error>) {
        self.result = result
    }
    
    public init(from decoder: Decoder) throws {
        self.result = try decodeResult(from: decoder,
                                       errorTypes: codableErrorTypes)
    }
    
    public func encode(to encoder: Encoder) throws {
        try encodeResult(result,
                         to: encoder,
                         errorTypes: codableErrorTypes)
    }
}


