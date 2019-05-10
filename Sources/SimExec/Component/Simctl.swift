import Foundation

public enum Simctl {
    public typealias Devices = [String: [Device]]
    
    public struct Device: Codable {
        public var state: String
        public var isAvailable: Bool
        public var name: String
        public var udid: String
    }

    public struct ListResponse: Codable {
        public var devices: Devices
    }
    
    public static func list() throws -> ListResponse {
        let args = [
            "xcrun", "simctl", "list", "--json"
        ]
        let data = try capture(arguments: args)
        return try ListResponse.decode(fromJSONData: data)
    }
    
    public static func boot(udid: String) throws {
        let args = [
            "xcrun", "simctl", "boot", udid
        ]
        try system(arguments: args)
    }
    
    public static func install(udid: String, appURL: URL) throws {
        let args = [
            "xcrun", "simctl", "install", udid, appURL.path
        ]
        try system(arguments: args)
    }
    
    public static func launch(udid: String, appID: String) throws {
        let args = [
            "xcrun", "simctl", "launch", "--console-pty", udid, appID
        ]
        try capture(arguments: args)
    }
}
