import Foundation

public protocol DecodableByProxy : Decodable {
    associatedtype CodableProxy : Decodable
    
    init(fromCodableProxy p: CodableProxy)
}

extension DecodableByProxy {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let p = try c.decode(CodableProxy.self)
        self.init(fromCodableProxy: p)
    }
}

public protocol EncodableByProxy : Encodable {
    associatedtype CodableProxy : Encodable
    
    func encodeToCodableProxy() -> CodableProxy
}

extension EncodableByProxy {
    public func encode(to encoder: Encoder) throws {
        let p = encodeToCodableProxy()
        var c = encoder.singleValueContainer()
        try c.encode(p)
    }
}
