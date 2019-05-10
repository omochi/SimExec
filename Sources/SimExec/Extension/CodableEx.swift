import Foundation

extension Decodable {
    public static func decode(fromJSONData data: Data) throws -> Self {
        let decoder = JSONDecoder()
        return try decoder.decode(self, from: data)
    }
}
