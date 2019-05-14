import Foundation
import Network
import RichJSONParser

public final class MessageConnection {
    private let connection: JSONConnection
    
    public var errorHandler: ((Error) -> Void)?
    public var closedHandler: (() -> Void)?
    public var receiveHandler: ((MessageProtocol) -> Void)?
    public var connectedHandler: (() -> Void)?
    
    public init(connection: NWConnection) {
        self.connection = JSONConnection(connection: connection)
    }
    
    public func start(queue: DispatchQueue) {
        connection.errorHandler = { [weak self] (error) in
            self?.errorHandler?(error)
        }
        connection.closedHandler = { [weak self] in
            self?.closedHandler?()
        }
        connection.receiveHandler = { [weak self] (json) in
            guard let self = self else {
                return
            }
            
            do {
                try self.onReceive(json: json)
            } catch {
                self.connection.close()
                self.errorHandler?(error)
            }
        }
        connection.connectedHandler = { [weak self] in
            self?.connectedHandler?()
        }
        
        connection.start(queue: queue)
    }
    
    public func close() {
        connection.close()
    }
    
    public func send(message: MessageProtocol) throws {
        let container = MessageCodableContainer(message)
        let json = try container.encodeToJSON()
        connection.send(json: json,
                        completionHandler: nil)
    }
    
    private func onReceive(json: ParsedJSON) throws {
        let container = try MessageCodableContainer.decode(from: json)
        receiveHandler?(container.value)
    }
}

