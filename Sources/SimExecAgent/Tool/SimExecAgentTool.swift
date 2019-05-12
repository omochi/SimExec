import Foundation
import SimExec

public final class SimExecAgentTool {
    public enum State {
        case ready
        case busy
    }
    
    public struct Request {
        public var source: String
        public var udid: String
        
        public init(source: String,
                    udid: String)
        {
            self.source = source
            self.udid = udid
        }
    }
    
    private let queue: DispatchQueue
    private var execQueue: DispatchQueue?
    private let fileSystem: FileSystem
    private var state: State
    
    public init() {
        let tag = "SimExecAgent"
        self.queue = DispatchQueue(label: tag)
        self.fileSystem = FileSystem(applicationName: tag)
        self.state = .ready
    }
    
    public func start() {
    }
    
    public func state(handler: @escaping (State) -> Void)
    {
        queue.async {
            handler(self.state)
        }
    }
    
    public func request(_ request: Request,
                        stateHandler: @escaping (SimExecTool.State) -> Void,
                        completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        queue.async {
            do {
                guard case .ready = self.state else {
                    throw MessageError("busy now")
                }
                
                self.state = .busy
                
                self.execQueue = DispatchQueue(label: "SimExecAgent.execQueue")
                
                self.execQueue!.async {
                    self.exec(request: request,
                              stateHandler: stateHandler,
                              completionHandler: completionHandler)
                }
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
    
    private func exec(request: Request,
                      stateHandler: @escaping (SimExecTool.State) -> Void,
                      completionHandler: @escaping (Result<Void, Error>) -> Void)
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
                    stateHandler(state)
                }
            }
            
            queue.async {
                stateHandler(.start)
            }
            
            try tool.run()
            
            queue.async {
                self.state = .ready
                completionHandler(.success(()))
            }
        } catch {
            queue.async {
                self.state = .ready
                completionHandler(.failure(error))
            }
        }
    }
    
    public static func main(arguments: [String]) throws -> Never {
        let tool = SimExecAgentTool()
        tool.start()
        dispatchMain()
    }
}

