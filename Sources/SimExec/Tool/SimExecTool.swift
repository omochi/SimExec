import Foundation

public final class SimExecTool {
    public struct Options {
        public var sourceFile: URL
        public var simulatorDeviceUDID: String
        public var keepTemporaryFiles: Bool
        
        public init(sourceFile: URL,
                    simulatorDeviceUDID: String,
                    keepTemporaryFiles: Bool)
        {
            self.sourceFile = sourceFile
            self.simulatorDeviceUDID = simulatorDeviceUDID
            self.keepTemporaryFiles = keepTemporaryFiles
        }
    }
    
    public enum State : String, Codable {
        case start
        case build
        case launch
        case running
        case complete
    }
    
    private let options: Options
    private let fileSystem: FileSystem
    private let logger: Logger
    
    public private(set) var state: State {
        didSet {
            stateHandler?(state)
        }
    }
    public var stateHandler: ((State) -> Void)?
    public var screenshotHandler: ((URL) -> Void)?
    
    private var projectDir: URL?
    private var buildDir: URL?
    private var simctl: Simctl?
    private var appFile: URL?
    public private(set) var outFile: URL?
    public private(set) var errorFile: URL?
    public private(set) var screenshotFiles: [URL] = []

    public init(options: Options) {
        let tag = "SimExecTool"
        self.options = options
        self.fileSystem = FileSystem(applicationName: tag)
        self.logger = Logger(tag: tag)
        self.state = State.start
    }
    
    public func run() throws {
        defer {
            if !options.keepTemporaryFiles {
                fileSystem.deleteKeepedTemporaryFiles()
            }
        }
        
        let simctl = Simctl(udid: options.simulatorDeviceUDID)
        self.simctl = simctl

        try assertDevice()
        try checkout()
        try build()
        try bootDevice()
        try installAppToDevice()
        try launchApp()
        try takeScreenshots()
        try terminateApp()
    }
    
    private func assertDevice() throws {
        let device = try simctl!.status()
        guard device.isAvailable else {
            throw MessageError("device not available: udid=\(device.udid)")
        }
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
        self.state = .build
        
        try fm.changeCurrentDirectory(to: projectDir!)
        
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
        
        self.buildDir = buildDir
        self.appFile = buildDir.appendingPathComponent("TempApp.app")
    }
    
    private func bootDevice() throws {
        self.state = .launch
        
        var device = try simctl!.status()
        if device.state == "Booted" {
            logger.debug("device is booted")
            return
        }
        
        logger.debug("boot device")
        try simctl!.boot()

        sleep(3)
            
        device = try simctl!.status()
        guard device.state == "Booted" else {
            throw MessageError("device boot failed")
        }
    }
    
    private func installAppToDevice() throws {
        logger.debug("install app")
        try simctl!.install(appURL: appFile!)
    }
    
    private func launchApp() throws {
        logger.debug("launch app")
        let dir = self.buildDir!
        try fm.changeCurrentDirectory(to: dir)
        
        self.outFile = dir.appendingPathComponent("out.txt")
        self.errorFile = dir.appendingPathComponent("error.txt")
        try simctl!.launch(appID: "simexec.TempApp",
                           outFile: outFile!,
                           errorFile: errorFile!)
    
        self.state = .running
    }
    
    private func takeScreenshots() throws {
        let dir = self.buildDir!
        for i in 0..<4 {
            sleep(3)
            let file = dir.appendingPathComponent("ss.\(i).png")
            logger.debug("take ss: \(file.path)")
            try simctl!.screenshot(file: file)
            screenshotFiles.append(file)
            screenshotHandler?(file)
        }
    }
    
    private func terminateApp() throws {
        logger.debug("terminate app")
        try simctl!.terminate(appID: "simexec.TempApp")
        
        self.state = .complete
    }
    
    public static func main(args: [String]) -> Never {
        do {
            let options = try Options.parse(args: args)
            let tool = SimExecTool(options: options)
            try tool.run()
            exit(EXIT_SUCCESS)
        } catch {
            fatalError("\(error)")
        }
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
