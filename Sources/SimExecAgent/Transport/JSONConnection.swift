import Foundation
import Network
import SimExec
import FineJSON
import RichJSONParser

public final class JSONConnection {
    public let connection: NWConnection
    private var receiveBuffer: Data
    private var sendQueue: [JSON]
    private var isSending: Bool
    public var errorHandler: ((Error) -> Void)?
    public var receiveHandler: ((ParsedJSON) -> Void)?
    public var closedHandler: (() -> Void)?
    public var connectedHandler: (() -> Void)?
    
    public init(connection: NWConnection) {
        self.connection = connection
        self.receiveBuffer = Data()
        self.sendQueue = []
        self.isSending = false
    }
    
    public func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] (state) in
            guard let self = self else { return }
            switch state {
            case .failed(let error):
                self.emitError(error)
            case .ready:
                self.connectedHandler?()
                self._send()
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive()
    }
    
    public func close() {
        connection.cancel()
    }
    
    public func send(json: JSON) {
        sendQueue.append(json)
        _send()
    }
    
    private func _send() {
        guard connection.state == .ready else {
            return
        }
        
        if isSending {
            return
        }
        
        if sendQueue.isEmpty {
            return
        }
        
        let json = sendQueue.removeFirst()
        
        let serializer = JSONSerializer()
        let body = serializer.serialize(json)
        
        let header = "length=\(body.count)\n\n"
        
        let data = header.data(using: .utf8)! + body
        
        isSending = true
        
        let completion: (Error?) -> Void = { [weak self] (error) in
            guard let self = self else { return }
            
            self.isSending = false
            
            if let error = error {
                self.emitError(error)
                return
            }
            
            self._send()
        }
        
        connection.send(content: data,
                        contentContext: .defaultStream,
                        isComplete: false,
                        completion: .contentProcessed(completion))
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self]
            (data, context, isFinished, error) in
            
            guard let self = self else { return }

            if let error = error {
                self.emitError(error)
                return
            }
            
            if let data = data {
                self.receiveBuffer.append(data)
                do {
                    try self.parse()
                } catch {
                    self.emitError(error)
                    return
                }
            }
            
            if isFinished {
                self.closedHandler?()
                self.connection.cancel()
                return
            }

            self.receive()
        }
    }
    
    private func emitError(_ error: Error) {
        errorHandler?(error)
        connection.cancel()
    }
    
    private func parse() throws {
        let sep = "\n\n".data(using: .utf8)!
        while true {
            if connection.state == .cancelled {
                return
            }
        
            guard let sepRange = receiveBuffer.firstRange(of: sep) else {
                return
            }
        
            guard let header = String(data: receiveBuffer[..<sepRange.lowerBound],
                                      encoding: .utf8) else
            {
                throw MessageError("invalid data received")
            }
            
            let lines = header.components(separatedBy: "\n")
            let fields = lines.compactMap { (line: String) -> (String, String)? in
                guard let eqPos = line.range(of: "=") else {
                    return nil
                }
                
                let key = String(line[..<eqPos.lowerBound])
                let value = String(line[eqPos.upperBound...])
                return (key, value)
            }
            let fieldMap: [String: String] = Dictionary(fields, uniquingKeysWith: { $1 })
            
            guard let lengthStr = fieldMap["length"],
                let length = Int(lengthStr) else
            {
                throw MessageError("no length")
            }
            
            let bodyStart = sepRange.upperBound
            let bodyEnd = bodyStart + length
            
            if receiveBuffer.count < bodyEnd {
                return
            }
            
            let body = receiveBuffer[bodyStart..<bodyEnd]
            receiveBuffer.removeSubrange(..<bodyEnd)
            
            let parser = try JSONParser(data: body)
            let json = try parser.parse()
            receiveHandler?(json)
        }
    }
    
}
