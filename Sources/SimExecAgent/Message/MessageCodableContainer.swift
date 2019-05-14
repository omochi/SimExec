import SimExec
import FineJSON

public struct MessageCodableContainer : Codable {
    public enum CodingKeys : CodingKey {
        case type
        case value
    }
    
    public var value: MessageProtocol
    
    public init(_ value: MessageProtocol) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let typeName = try c.decode(String.self, forKey: .type)
        guard let type: MessageProtocol.Type = (messageTypes.first { $0.name == typeName }) else {
            throw DecodingError.custom(message: "unknown type: \(typeName)",
                codingPath: decoder.codingPath,
                location: decoder.sourceLocation)
        }
        let value = try type.dispatch_KeyedDecodingContainer_decode(container: c, forKey: .value)
        self.init(value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(type(of: value).name, forKey: .type)
        try value.dispatch_KeyedEncodingContainer_encode(container: &c, forKey: .value)
    }
}
