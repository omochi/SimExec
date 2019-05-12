import Foundation
import Network
import RichJSONParser
import SimExec

public final class SimExecAgentSocketAdapter {
    private let agent: SimExecAgentTool
    private let queue: DispatchQueue
    private let logger: Logger
    private let nwListener: NWListener
    private var connections: [JSONConnection]
    
    public var errorHandler: ((Error) -> Void)?
    
    public init(agent: SimExecAgentTool,
                queue: DispatchQueue) throws {
        self.agent = agent
        self.queue = queue
        self.logger = Logger(tag: "SimExecAgentSocketAdapter")
        self.nwListener = try NWListener(using: NWParameters(tls: nil),
                                         on: NWEndpoint.Port(35120))
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
        
        nwListener.start(queue: queue)
    }
    
    private func onNewConnection(_ connection: NWConnection) {
        let conn = JSONConnection(connection: connection)
        
        conn.errorHandler = { [weak self, weak conn] (error) in
            guard let self = self,
                let conn = conn else { return }
            
            self.logger.error("\(error)")
            self.removeConneciton(conn)
        }

        conn.receiveHandler = { [weak self, weak conn] (json) in
            guard let self = self,
                let conn = conn else { return }
            
            do {
                try self.onReceive(connection: conn, json: json)
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
        
        conn.start(queue: queue)
    }
    
    private func removeConneciton(_ connection: JSONConnection) {
        connection.close()
        connections.removeAll { $0 === connection }
    }
    
    private func onReceive(connection: JSONConnection,
                           json: ParsedJSON) throws
    {
        
    }
}
