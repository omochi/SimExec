import Foundation
import SimExec

public final class SimExecAgentTool {
    public enum State : String, Codable {
        case ready
        case start
        case build
        case launch
        case running
        
        public init(from state: SimExecTool.State) {
            switch state {
            case .start: self = .start
            case .build: self = .build
            case .launch: self = .launch
            case .running: self = .running
            case .complete: self = .ready
            }
        }
    }
    
    public struct Request : Codable {
        public var source: String
        public var udid: String
        
        public init(source: String,
                    udid: String)
        {
            self.source = source
            self.udid = udid
        }
    }
    
    public struct Response : Codable {
        public var out: String
        public var error: String
    }
    
    public let queue: DispatchQueue
    private var adapter: SimExecAgentSocketAdapter!
    private var execQueue: DispatchQueue?
    private let fileSystem: FileSystem
    public private(set) var state: State {
        didSet {
            stateHandler?(state)
        }
    }
    
    public var stateHandler: ((State) -> Void)?
    public var screenshotHandler: ((URL) -> Void)?
    
    public init(queue: DispatchQueue) throws {
        let tag = "SimExecAgent"
        self.queue = queue
        self.fileSystem = FileSystem(applicationName: tag)
        self.state = .ready
        
        self.adapter = try SimExecAgentSocketAdapter(agent: self,
                                                     fileSystem: fileSystem)
    }
    
    deinit {
        print("SimExecAgent.deinit")
        
        terminate()
    }
    
    public func terminate() {
        self.adapter.terminate()
    }

    public func request(_ request: Request,
                        completionHandler: @escaping (Result<Response, Error>) -> Void)
    {
        do {
            guard case .ready = self.state else {
                throw MessageError("not ready now")
            }
            
            self.state = .start
            
            let execQueue = DispatchQueue(label: "SimExecAgent.execQueue")
            self.execQueue = execQueue
            
            execQueue.async {
                self.exec(request: request,
                          completionHandler: completionHandler)
            }
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    private func exec(request: Request,
                      completionHandler: @escaping (Result<Response, Error>) -> Void)
    {
        do {
            let fs = FileSystem(applicationName: "SimExecAgentTool")
            defer {
                fs.deleteKeepedTemporaryFiles()
            }
            
            let workDir = try fs.makeTemporaryDirectory(name: "work", deleteAfter: true)
            let sourceFile = workDir.appendingPathComponent("ViewController.swift")
            try request.source.write(to: sourceFile, atomically: true, encoding: .utf8)
            
            let options = SimExecTool.Options(sourceFile: sourceFile,
                                              simulatorDeviceUDID: request.udid,
                                              keepTemporaryFiles: false)
            let tool = SimExecTool(options: options)
            
            tool.stateHandler = { (state) in
                self.queue.async {
                    self.state = State(from: state)
                }
            }
            tool.screenshotHandler = { (file) in
                self.queue.async {
                    self.screenshotHandler?(file)
                }
            }
            
            try tool.run()
            
            let out = try Data(contentsOf: tool.outFile!).toUTF8Robust()
            let err = try Data(contentsOf: tool.errorFile!).toUTF8Robust()
            
            let response = SimExecAgentTool.Response(out: out,
                                                     error: err)
            
            queue.async {
                completionHandler(.success(response))
            }
        } catch {
            queue.async {
                self.state = .ready
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func main(arguments: [String]) -> Never {
        do {
            let tool = try SimExecAgentTool(queue: DispatchQueue.main)
            _ = tool
            dispatchMain()
        } catch {
            fatalError("\(error)")
        }
    }
}

