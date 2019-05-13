import Foundation
import Network
import SimExec

public final class SimExecAgentClient {
    public typealias ResponseHandler = (Result<ResponseMessageProtocol, Error>) -> Void
    
    private final class ResponseHandlerBuilder {
        public let requestID: Int
        private weak var client: SimExecAgentClient?
        
        private var completionHandler: (ResponseMessageProtocol.Type, ResponseHandler)?
        private var eventHandlers: [(ResponseMessageProtocol.Type, (ResponseMessageProtocol) -> Void)] = []
        
        public init(requestID: Int,
                    client: SimExecAgentClient) {
            self.requestID = requestID
            self.client = client
        }
        
        public func register() {
            guard let client = self.client else { return }
            let handler = { (response: Result<ResponseMessageProtocol, Error>) in
                self.process(response: response)
            }
            client.setResponseHandler(requestID: requestID,
                                      handler)
        }
        
        public func addEventHandler<T: ResponseMessageProtocol>(
            type: T.Type,
            handler: @escaping (T) -> Void)
        {
            let handler2 = { (response: ResponseMessageProtocol) in
                handler(response as! T)
            }
            
            eventHandlers.append((type, handler2))
        }
        
        public func setCompletionHandler<T: ResponseMessageProtocol>(
            type: T.Type,
            handler: @escaping (Result<T, Error>) -> Void
            )
        {
            let handler2 = { (response: Result<ResponseMessageProtocol, Error>) in
                handler(response.map { $0 as! T })
            }
            
            completionHandler = (type, handler2)
        }
        
        public func process(response: Result<ResponseMessageProtocol, Error>) {
            guard let client = self.client else {
                return
            }
            
            do {
                let response = try response.get()
                
                let responseType = type(of: response)
                
                if responseType == completionHandler?.0 {
                    client.clearResponseHandler(requestID: requestID)
                    completionHandler?.1(.success(response))
                    return
                }
                
                for eventHandler in eventHandlers {
                    if responseType == eventHandler.0 {
                        eventHandler.1(response)
                    }
                    return
                }
            } catch {
                client.clearResponseHandler(requestID: requestID)
                completionHandler?.1(.failure(error))
            }
        }
    }
    
    private let host: String
    private let connection: MessageConnection
    private let queue: DispatchQueue
    
    private var lastRequestID: Int
    private var responseHandlers: [Int: ResponseHandler] = [:]
    
    public var errorHandler: ((Error) -> Void)?
    
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
        
        connection.errorHandler = { [weak self] (error) in
            self?.onConnectionError(error)
        }
        connection.closedHandler = { [weak self] () in
            self?.onConnectionClosed()
        }
        connection.receiveHandler = { [weak self] (message) in
            self?.onReceive(message: message)
        }
    }

    public func start() {
        connection.start(queue: queue)
    }
    
    public func state(handler: @escaping (Result<SimExecAgentTool.State, Error>) -> Void)
    {
        execute(makeRequest: { (qid) in
            StateRequest(requestID: qid) }
        ) { (builder) in
            builder.setCompletionHandler(type: StateResponse.self) { (response) in
                handler(response.map { $0.state })
            }
        }
    }
    
    public func request(_ request: SimExecAgentTool.Request,
                        stateHandler: @escaping (SimExecTool.State) -> Void,
                        completionHandler: @escaping (Result<SimExecAgentTool.Response, Error>) -> Void)
    {
        execute(makeRequest: { (qid) in
            AgentRequestRequest(requestID: qid, request: request) }
        ) { (builder) in
            builder.addEventHandler(type: AgentRequestStateEvent.self) { (response) in
                stateHandler(response.state)
            }
            builder.setCompletionHandler(type: AgentRequestResponse.self) { (response) in
                completionHandler(response.map { $0.response })
            }
        }
    }
    
    private func execute(makeRequest: (Int) -> RequestMessageProtocol,
                         configure: (ResponseHandlerBuilder) -> Void)
    {
        let qid = lastRequestID + 1
        lastRequestID = qid
        
        let builder = ResponseHandlerBuilder(requestID: qid,
                                             client: self)
        configure(builder)
        builder.register()
        
        do {
            let request = makeRequest(qid)
            try connection.send(message: request)
        } catch {
            builder.process(response: .failure(error))
        }
    }
    
    
    private func setResponseHandler(requestID: Int,
                                    _ handler: @escaping ResponseHandler)
    {
        responseHandlers[requestID] = handler
    }

    private func clearResponseHandler(requestID: Int) {
        responseHandlers.removeValue(forKey: requestID)
    }
    
    private func onConnectionError(_ error: Error) {
        handleError(error)
    }
    
    private func onConnectionClosed() {
        handleError(MessageError("connection closed"))
    }
    
    private func onReceive(message: MessageProtocol) {
        if let error = message as? RequestErrorResponse {
            if let handler = responseHandlers[error.requestID] {
                clearResponseHandler(requestID: error.requestID)
                handler(.failure(error))
            }
            return
        }
        if let response = message as? ResponseMessageProtocol {
            if let handler = responseHandlers[response.requestID] {
                clearResponseHandler(requestID: response.requestID)
                handler(.success(response))
            }
        }
    }
    
    private func handleError(_ error: Error) {
        let handlers = responseHandlers
        responseHandlers.removeAll()
        for (_, handler) in handlers {
            handler(.failure(error))
        }
        errorHandler?(error)
    }
}
