import Foundation
import Network
import SimExec

public final class SimExecAgentClient {    
    private let host: String
    private let connection: MessageConnection
    private let fileSystem: FileSystem
    private let queue: DispatchQueue
    
    public private(set) var state: SimExecAgentTool.State = .ready {
        didSet {
            stateHandler?(state)
        }
    }
    public var stateHandler: ((SimExecAgentTool.State) -> Void)?
    public var screenshotHandler: ((URL) -> Void)?
    public var errorHandler: ((Error) -> Void)?
    
    private var requestCompletionHandler: ((Result<SimExecAgentTool.Response, Error>) -> Void)?
    
    public init(host: String,
                queue: DispatchQueue)
    {
        self.host = host
        self.queue = queue
        self.fileSystem = FileSystem(applicationName: "SimExecAgentClient")

        let conn = NWConnection(host: NWEndpoint.Host(host),
                                port: SimExecAgentSocketAdapter.port,
                                using: NWParameters(tls: nil))
        self.connection = MessageConnection(connection: conn,
                                            fileSystem: fileSystem)
        
        connection.errorHandler = { [weak self] (error) in
            self?.onConnectionError(error)
        }
        connection.closedHandler = { [weak self] () in
            self?.onConnectionClosed()
        }
        connection.receiveHandler = { [weak self] (message) in
            self?.onReceive(message: message)
        }
        connection.fileHandler = { [weak self] (file) in
            self?.onFile(file)
        }
    }

    public func start() {
        connection.start(queue: queue)
    }
    
    public func request(_ request: SimExecAgentTool.Request,
                        completionHandler: @escaping (Result<SimExecAgentTool.Response, Error>) -> Void)
    {
        do {
            try connection.send(message: AgentRequestRequest(request: request))
            requestCompletionHandler = completionHandler
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    private func onConnectionError(_ error: Error) {
        handleError(error)
    }
    
    private func onConnectionClosed() {
        handleError(MessageError("connection closed"))
    }
    
    private func onReceive(message: MessageProtocol) {
        switch message {
        case let m as AgentStateEvent:
            self.state = m.state
        case let m as AgentRequestResponse:
            let h = requestCompletionHandler.take()
            h?(m.result)
        default:
            handleError(MessageError("unknown message: \(type(of: message))"))
        }
    }
    
    private func onFile(_ file: URL) {
        screenshotHandler?(file)
    }
    
    private func handleError(_ error: Error) {
        let h = requestCompletionHandler.take()
        h?(.failure(error))
        errorHandler?(error)
    }
}
