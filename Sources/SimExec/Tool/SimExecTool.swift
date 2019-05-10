import Foundation

public final class SimExecTool {
    public struct Options {
        public var sourceFile: URL
        public var simulatorDeviceUDID: String
        public var keepTemporaryFiles: Bool
    }
    
    private let options: Options
    private let fileSystem: FileSystem
    private let logger: Logger
    private let resourceDirectory: URL
    
    private var projectDir: URL!
    private var buildDir: URL!
    private var appFile: URL!

    public init(options: Options) {
        let tag = "SimExecTool"
        self.options = options
        self.fileSystem = FileSystem(applicationName: tag)
        self.logger = Logger(tag: tag)
        self.resourceDirectory = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
    }
    
    public func run() -> Never {
        do {
            try _run()
        } catch {
            logger.critical("\(error)")
            exit(EXIT_FAILURE)
        }
        exit(EXIT_SUCCESS)
    }
    
    private func _run() throws {
        defer {
            if !options.keepTemporaryFiles {
                fileSystem.deleteKeepedTemporaryFiles()
            }
        }
        
        try assertDevice()
        try checkout()
        try build()
        try bootDevice()
        try installAppToDevice()
        try launchApp()
    }
    
    private func assertDevice() throws {
        let device = try deviceStatus()
        guard device.isAvailable else {
            throw MessageError("device not available: udid=\(device.udid)")
        }
    }
    
    private func deviceStatus() throws -> Simctl.Device {
        let udid = options.simulatorDeviceUDID
        let res = try Simctl.list()
        guard let device = (res.devices.flatMap { $1 }.first { $0.udid == udid }) else {
            throw MessageError("device not found: udid=\(udid)")
        }
        return device
    }
    
    private func checkout() throws {
        let checkoutDir = try fileSystem.makeTemporaryDirectory(name: "checkout", deleteAfter: true)

        let projDir = checkoutDir
            .appendingPathComponent("TempApp")
        let templateDir = resourceDirectory
            .appendingPathComponent("TempAppTemplate")
        try fm.copyItem(at: templateDir, to: projDir)
        
        let sourceDestPath = projDir
            .appendingPathComponent("TempApp")
            .appendingPathComponent("ViewController.swift")
        try fm.copyItem(at: options.sourceFile, to: sourceDestPath, overwrite: true)
        
        logger.debug("projDir=\(projDir.path)")
        
        self.projectDir = projDir
    }
    
    private func build() throws {
        try fm.changeCurrentDirectory(to: projectDir)
        
        let sdks = try Xcodebuild.showSDKs()
        guard let sdk = (sdks.first {
            $0.platform == "iphonesimulator" && $0.sdkVersion == "12.2" }) else
        {
            throw MessageError("sdk not found")
        }
        
        let xcodebuild = Xcodebuild(project: URL(fileURLWithPath: "TempApp.xcodeproj"),
                                    scheme: "TempApp",
                                    configuration: "Debug",
                                    sdk: sdk.canonicalName)
        let buildSettingsResponse = try xcodebuild.showBuildSettings()
        guard let item = (buildSettingsResponse.first {
            $0.action == "build" && $0.target == "TempApp" }) else
        {
            throw MessageError("build setting not found")
        }
        guard let buildDirStr = item.buildSettings["CONFIGURATION_BUILD_DIR"] else {
            throw MessageError("no CONFIGURATION_BUILD_DIR")
        }
        let buildDir = URL(fileURLWithPath: buildDirStr)
        logger.debug("buildDir=\(buildDir.path)")
        
        try xcodebuild.build(destinationUDID: options.simulatorDeviceUDID)
        logger.debug("build ok")
        
        self.buildDir = buildDir
        self.appFile = buildDir.appendingPathComponent("TempApp.app")
    }
    
    private func bootDevice() throws {
        var device = try deviceStatus()
        if device.state == "Booted" {
            return
        }
        
        let udid = options.simulatorDeviceUDID
        try Simctl.boot(udid: udid)

        sleep(3)
            
        device = try deviceStatus()
        guard device.state == "Booted" else {
            throw MessageError("device boot failed")
        }
    }
    
    private func installAppToDevice() throws {
        let udid = options.simulatorDeviceUDID
        try Simctl.install(udid: udid, appURL: appFile)
    }
    
    private func launchApp() throws {
        let udid = options.simulatorDeviceUDID
        try Simctl.launch(udid: udid, appID: "simexec.TempApp")
    }
    
    public static func main(args: [String]) throws -> Never {
        let options = try Options.parse(args: args)
        let tool = SimExecTool(options: options)
        tool.run()
    }
}

extension SimExecTool.Options {
    public static func parse(args: [String]) throws -> SimExecTool.Options {
        var args = args
        args.removeFirst()
        
        var sourceOrNone: URL?
        var deviceOrNone: String?
        var keepTemps: Bool = false
        
        var i = 0
        
        func takeValue(key: String) throws -> String? {
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
        
        func takeFlag(key: String) -> Bool {
            let arg = args[i]
            guard arg == key else {
                return false
            }
            i += 1
            return true
        }
        
        while i < args.count {
            if let sourceStr = try takeValue(key: "--source") {
                sourceOrNone = URL(fileURLWithPath: sourceStr)
                continue
            }
            if let deviceStr = try takeValue(key: "--device") {
                deviceOrNone = deviceStr
                continue
            }
            if takeFlag(key: "--keep-temps") {
                keepTemps = true
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
        
        return SimExecTool.Options(sourceFile: source,
                                   simulatorDeviceUDID: device,
                                   keepTemporaryFiles: keepTemps)
    }
}
