import Foundation
import Network
import RichJSONParser
import SimExec

public final class SimExecAgentSocketAdapter {
    public static let port: NWEndpoint.Port = NWEndpoint.Port(35120)
    
    unowned let agent: SimExecAgentTool
    private var queue: DispatchQueue {
        return agent.queue
    }
    private let logger: Logger
    private let nwListener: NWListener
    private var connections: [MessageConnection]
    
    public var errorHandler: ((Error) -> Void)?
    
    public init(agent: SimExecAgentTool) throws {
        self.agent = agent
        self.logger = Logger(tag: "SimExecAgentSocketAdapter")
        self.nwListener = try NWListener(using: NWParameters(tls: nil),
                                         on: SimExecAgentSocketAdapter.port)
        self.connections = []

        nwListener.stateUpdateHandler = { [weak self] (state) in
            guard let self = self else { return }
            
            switch state {
            case .failed(let error):
                self.errorHandler?(error)
                return
            default:
                return
            }
        }
        
        nwListener.newConnectionHandler = { [weak self] (connection) in
            self?.onNewConnection(connection)
        }
        
        agent.stateHandler = { [weak self] (state) in
            guard let self = self else { return }
            
            for conn in self.connections {
                self.send(conneciton: conn, message: AgentStateEvent(state: state))
            }
        }
        
        nwListener.start(queue: queue)
    }
    
    public func terminate() {
        for connection in connections {
            connection.close()
        }
        connections.removeAll()
        
        nwListener.cancel()
    }
    
    private func onNewConnection(_ connection: NWConnection) {
        let conn = MessageConnection(connection: connection)
        
        conn.errorHandler = { [weak self, weak conn] (error) in
            guard let self = self,
                let conn = conn else { return }
            
            self.logger.error("\(error)")
            self.removeConneciton(conn)
        }

        conn.receiveHandler = { [weak self, weak conn] (message) in
            guard let self = self,
                let conn = conn else { return }
            
            do {
                try self.onReceive(connection: conn, message: message)
            } catch {
                self.logger.error("\(error)")
                self.removeConneciton(conn)
            }
        }
        
        conn.closedHandler = { [weak self, weak conn] in
            guard let self = self,
                let conn = conn else { return }
            self.removeConneciton(conn)
        }

        connections.append(conn)
        
        conn.start(queue: queue)
        
        send(conneciton: conn, message: AgentStateEvent(state: agent.state))
    }
    
    private func removeConneciton(_ connection: MessageConnection) {
        connection.close()
        connections.removeAll { $0 === connection }
    }
    
    private func isValid(connection: MessageConnection) -> Bool {
        return connections.contains { $0 === connection }
    }
    
    private func onReceive(connection: MessageConnection,
                           message: MessageProtocol) throws
    {
        switch message {
        case let m as AgentRequestRequest:
            agent.request(m.request,
                          completionHandler:
                { (response) in
                    self.send(conneciton: connection,
                              message: AgentRequestResponse(response: response.value,
                                                            error: response.error.map { "\($0)" }))
            })
        default:
            throw MessageError("unsupported message: \(type(of: message))")
        }
    }
    
    private func send(conneciton: MessageConnection,
                      message: MessageProtocol)
    {
        guard isValid(connection: conneciton) else {
            return
        }
        do {
            try conneciton.send(message: message)
        } catch {
            logger.error("\(error)")
            removeConneciton(conneciton)
        }
    }
}
