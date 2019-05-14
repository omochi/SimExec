import Foundation
import FineJSON
import RichJSONParser

extension Decodable {
    public static func decode(fromJSONData data: Data) throws -> Self {
        let decoder = FineJSONDecoder()
        return try decoder.decode(self, from: data)
    }
    
    public static func decode(from json: ParsedJSON) throws -> Self {
        let decoder = FineJSONDecoder()
        return try decoder.decode(self, from: json)
    }
    
    public static func dispatch_KeyedDecodingContainer_decode<K>(container: KeyedDecodingContainer<K>,
                                                                 forKey key: K)
        throws -> Self
    {
        return try container.decode(self, forKey: key)
    }
}

extension Encodable {
    public func encodeToJSON() throws -> JSON {
        let encoder = FineJSONEncoder()
        return try encoder.encodeToJSON(self)
    }
    
    public func dispatch_KeyedEncodingContainer_encode<K>(container: inout KeyedEncodingContainer<K>,
                                                          forKey key: K)
        throws
    {
        try container.encode(self, forKey: key)
    }
}
