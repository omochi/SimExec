import Foundation

public struct Simctl {
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
    
    public func status() throws -> Device {
        let res = try Simctl.list()
        let devices = res.devices.flatMap { $1 }
        guard let device = (devices.first { $0.udid == udid }) else {
            throw MessageError("device not found: udid=\(udid)")
        }
        return device
    }
    
    public func boot() throws {
        let args = [
            "xcrun", "simctl", "boot", udid
        ]
        try system(arguments: args)
    }
    
    public func install(appURL: URL) throws {
        let args = [
            "xcrun", "simctl", "install", udid, appURL.path
        ]
        try system(arguments: args)
    }
    
    public func launch(appID: String,
                       outFile: URL? = nil,
                       errorFile: URL? = nil)
        throws
    {
        var args = [
            "xcrun", "simctl", "launch",
        ]
        if let outFile = outFile {
            args.append("--stdout=\(outFile.path)")
        }
        if let errorFile = errorFile {
            args.append("--stderr=\(errorFile.path)")
        }
        args += [udid, appID]
        try system(arguments: args)
    }
    
    public func screenshot(file: URL) throws
    {
        let args = [
            "xcrun", "simctl", "io", udid, "screenshot",
            "--type=png", file.path
        ]
        try system(arguments: args)
    }
    
    public func terminate(appID: String) throws {
        let args = [
            "xcrun", "simctl", "terminate", udid, appID
        ]
        try system(arguments: args)
    }
    
    public var udid: String
}
