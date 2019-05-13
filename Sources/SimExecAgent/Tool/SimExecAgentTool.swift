import Foundation
import SimExec

public final class SimExecAgentTool {
    public enum State : String, Codable {
        case ready
        case busy
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
    private let adapter: SimExecAgentSocketAdapter
    private var execQueue: DispatchQueue?
    private let fileSystem: FileSystem
    private var state: State
    
    public init(queue: DispatchQueue) throws {
        let tag = "SimExecAgent"
        self.queue = queue
        self.fileSystem = FileSystem(applicationName: tag)
        self.state = .ready
        self.adapter = try SimExecAgentSocketAdapter()
        adapter.agent = self
        adapter.start()
    }
    
    public func state(handler: @escaping (State) -> Void)
    {
        queue.async {
            handler(self.state)
        }
    }
    
    public func request(_ request: Request,
                        stateHandler: @escaping (SimExecTool.State) -> Void,
                        completionHandler: @escaping (Result<Response, Error>) -> Void)
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
                    stateHandler(state)
                }
            }
            
            queue.async {
                stateHandler(.start)
            }
            
            try tool.run()
            
            let out = try Data(contentsOf: tool.outFile!).toUTF8Robust()
            let err = try Data(contentsOf: tool.errorFile!).toUTF8Robust()
            
            let response = SimExecAgentTool.Response(out: out,
                                                     error: err)
            
            queue.async {
                self.state = .ready
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
            _ = try SimExecAgentTool(queue: DispatchQueue.main)
            dispatchMain()
        } catch {
            fatalError("\(error)")
        }
    }
}

