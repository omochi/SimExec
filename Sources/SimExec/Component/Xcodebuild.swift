import Foundation

public struct Xcodebuild {
    public struct BuildError : ErrorBase {
        public var out: Data
        public var error: Data
        
        public var description: String {
            let lines = [
                "output:",
                out.toUTF8Robust(),
                "error:",
                error.toUTF8Robust()
            ]
            return lines.joined(separator: "\n")
        }
    }
    
    public struct SDK : Codable {
        public var canonicalName: String
        public var displayName: String
        public var platform: String
        public var sdkVersion: String
    }
    
    public typealias ShowSDKsResponse = [SDK]
    
    public typealias BuildSettings = [String: String]
    
    public struct ShowBuildSettingsResponseItem : Codable {
        public var action: String
        public var buildSettings: BuildSettings
        public var target: String
    }
    
    public typealias ShowBuildSettingsResponse = [ShowBuildSettingsResponseItem]
    
    public var project: URL
    public var scheme: String
    public var configuration: String
    public var sdk: String
    
    private func baseArgs() -> [String] {
        return [
            "xcodebuild",
            "-project", project.path,
            "-scheme", scheme,
            "-configuration", configuration,
            "-sdk", sdk
        ]
    }
    
    public static func showSDKs() throws -> ShowSDKsResponse {
        let args = [
            "xcodebuild", "-showsdks", "-json"
        ]
        let out = try capture(arguments: args)
        return try ShowSDKsResponse.decode(fromJSONData: out)
    }
    
    public func showBuildSettings() throws -> ShowBuildSettingsResponse {
        let args = baseArgs() + [
            "-showBuildSettings",
            "-json"
        ]
        let out = try capture(arguments: args)
        return try ShowBuildSettingsResponse.decode(fromJSONData: out)
    }
    
    
    public func build(destinationUDID: String) throws {
        let args = baseArgs() + [
            "-destination", "id=\(destinationUDID)"
        ]
        
        var out = Data()
        var error = Data()
        let p = try runProcess(arguments: args,
                               out: Pipe.output { (d) in
                                out.append(d) },
                               error: Pipe.output { (d) in
                                error.append(d) })
        
        guard p.terminationStatus == EXIT_SUCCESS else {
            throw BuildError(out: out, error: error)
        }
    }
}
    
