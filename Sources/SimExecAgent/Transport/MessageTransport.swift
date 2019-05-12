import Foundation
import Network
import SimExec

public final class MessageConnection {
    private let connection: NWConnection
    private var buffer: Data
    public var errorHandler: ((Error) -> Void)?
    
    public init(connection: NWConnection) {
        self.connection = connection
        self.buffer = Data()
    }
    
    public func start(queue: DispatchQueue) {
        receive()
        
        connection.start(queue: queue)
    }
    
    public func close() {
        connection.cancel()
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
                self.buffer.append(data)
                do {
                    try self.parse()
                } catch {
                    self.emitError(error)
                    return
                }
            }
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
        
            guard let sepRange = buffer.firstRange(of: sep) else {
                return
            }
        
            guard let header = String(data: buffer[..<sepRange.lowerBound],
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
            
            if buffer.count < bodyEnd {
                return
            }
            
            let body = buffer[bodyStart..<bodyEnd]
            buffer.removeSubrange(..<bodyEnd)
            
            
        }
    }
    
}
