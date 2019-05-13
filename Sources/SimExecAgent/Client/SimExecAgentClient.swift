import Foundation
import Network

public final class SimExecAgentClient {
    private let host: String
    private let connection: MessageConnection
    private let queue: DispatchQueue
    
    public var errorHandler: ((Error) -> Void)?
    public var connectedHandler: (() -> Void)?
    
    private var lastRequestID: Int
    private var responseHandlers: [Int: (MessageProtocol) -> Void] = [:]
    
    public init(host: String,
                queue: DispatchQueue)
    {
        self.host = host
        self.queue = queue

        let conn = NWConnection(host: NWEndpoint.Host(host),
                                port: SimExecAgentSocketAdapter.port,
                                using: NWParameters(tls: nil))
        self.connection = MessageConnection(connection: conn)
        
        self.lastRequestID = 0
    }

    public func start() {
        connection.start(queue: queue)
    }
    
    public func state(handler: @escaping (Result<SimExecAgentTool.State, Error>) -> Void)
    {
        do {
            let qid = lastRequestID + 1
            lastRequestID = qid
            
            try connection.send(message: StateRequest(requestID: qid))
            setResponseHandler(requestID: qid) { (response) in
                guard case let resp as StateResponse = response else {
                    return
                }

                
            }
        } catch {
            errorHandler?(error)
        }
    }
    
    private func setResponseHandler(requestID: Int,
                                    _ handler: @escaping (MessageProtocol) -> Void)
    {
        responseHandlers[requestID] = handler
    }
    
    private func clearResponseHandler(requestID: Int) {
        responseHandlers.removeValue(forKey: requestID)
    }
}
