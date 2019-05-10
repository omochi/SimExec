import Foundation

public final class SimExecTool {
    public struct Options {
        public var sourceFile: URL
        public var simulatorDeviceUUID: String
    }
    
    public let options: Options
    
    public init(options: Options) {
        self.options = options
    }
    
    public func run() throws {
        print(options)
    }
    
    public static func parseOptions(args: [String]) throws -> Options {
        var args = args
        args.removeFirst()
        
        var sourceOrNone: URL?
        var deviceOrNone: String?
        
        var i = 0
        
        func takeOption(key: String) throws -> String? {
            let arg = args[i]
            guard arg == key else {
                return nil
            }
            i += 1
            guard i < args.count else {
                throw MessageError("parameter not specified for \(key)")
            }
            let opt = args[i]
            i += 1
            return opt
        }
        
        while i < args.count {
            if let sourceStr = try takeOption(key: "--source") {
                sourceOrNone = URL(fileURLWithPath: sourceStr)
                continue
            }
            if let deviceStr = try takeOption(key: "--device") {
                deviceOrNone = deviceStr
                continue
            }
            break
        }
        
        guard let source = sourceOrNone else {
            throw MessageError("source not specified")
        }
        guard let device = deviceOrNone else {
            throw MessageError("device not specified")
        }
        
        return Options(sourceFile: source,
                       simulatorDeviceUUID: device)
    }
    
    public static func main(args: [String]) throws {
        let options = try parseOptions(args: args)
        let tool = SimExecTool(options: options)
        try tool.run()
    }
}
