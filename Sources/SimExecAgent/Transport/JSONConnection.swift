import Foundation
import Network
import SimExec
import FineJSON
import RichJSONParser

public final class JSONConnection {
    private struct SendTask {
        public enum Content {
            case json(JSON)
            case file(id: IDHolder)
        }
        
        public var content: Content
        public var completionHandler: (() -> Void)?
    }
    
    private struct FileSend {
        public var id: IDHolder
        public var file: URL
        public var sentSize: Int
        public var totalSize: Int?
        public var stream: InputStream?
    }
    
    public let connection: NWConnection
    private var receiveBuffer: Data
    private var sendQueue: [SendTask]
    private var isSending: Bool
    private let idPool: IDPool
    private var fileSends: [Int: FileSend]
    
    public var errorHandler: ((Error) -> Void)?
    public var receiveHandler: ((ParsedJSON) -> Void)?
    public var closedHandler: (() -> Void)?
    public var connectedHandler: (() -> Void)?
    
    public init(connection: NWConnection) {
        self.connection = connection
        self.receiveBuffer = Data()
        self.sendQueue = []
        self.isSending = false
        self.idPool = IDPool()
        self.fileSends = [:]
    }
    
    public func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] (state) in
            guard let self = self else { return }
            switch state {
            case .failed(let error):
                self.emitError(error)
            case .ready:
                self.connectedHandler?()
                self.driveSending()
            default:
                break
            }
        }
        connection.start(queue: queue)
        receive()
    }
    
    public func close() {
        connection.cancel()
        
        for fileSend in fileSends.values {
            if let stream = fileSend.stream {
                stream.close()
            }
        }
        fileSends.removeAll()
    }
    
    public func send(json: JSON,
                     completionHandler: (() -> Void)?)
    {
        let task = SendTask(content: .json(json),
                            completionHandler: completionHandler)
        sendQueue.append(task)
        driveSending()
    }
    
    public func send(file: URL)
    {
        let fileSend = FileSend(id: idPool.create(),
                                file: file,
                                sentSize: 0,
                                totalSize: nil,
                                stream: nil)
        fileSends[fileSend.id.id] = fileSend
        let task = SendTask(content: .file(id: fileSend.id),
                            completionHandler: nil)
        sendQueue.append(task)
        driveSending()
    }
    
    private func driveSending() {
        guard connection.state == .ready else {
            return
        }
        
        if isSending {
            return
        }
        
        if sendQueue.isEmpty {
            return
        }
        
        let task = sendQueue.removeFirst()
        
        switch task.content {
        case .json(let json):
            let serializer = JSONSerializer()
            let body = serializer.serialize(json)
            let data = build(body: body, fields: [:])
            _send(data: data) { () in
                task.completionHandler?()
            }
        case .file(id: let idHolder):
            do {
                try _send(fileSendID: idHolder.id, task: task)
            } catch {
                self.emitError(error)
            }
        }
    }
    
    private func _send(fileSendID id: Int,
                       task: SendTask) throws
    {
        var fileSend = fileSends[id]!
        
        if fileSend.stream == nil {
            let attrs = try fm.attributesOfItem(at: fileSend.file)
            
            guard let size = attrs[FileAttributeKey.size] as? Int else {
                throw MessageError("unknown file size: \(fileSend.file.path)")
            }
            
            guard let stream = InputStream(url: fileSend.file) else {
                throw MessageError("InputStream init failed: \(fileSend.file.path)")
            }
            
            stream.open()
            
            if let error = stream.streamError {
                throw error
            }
            
            fileSend.stream = stream
            fileSend.totalSize = size
            self.update(fileSend: fileSend)
        }
        
        let sendSize = min(1024, fileSend.totalSize! - fileSend.sentSize)
        
        var chunk = Data(count: sendSize)
        let streamReadSize = chunk.withUnsafeMutableBytes {
            (buf: UnsafeMutableRawBufferPointer) -> Int in
            fileSend.stream!.read(buf.bindMemory(to: UInt8.self).baseAddress!,
                                  maxLength: sendSize)
        }
        precondition(sendSize == streamReadSize)
        
        let data = build(body: chunk,
                         fields: [
                            "file": "\(id)",
                            "name": fileSend.file.lastPathComponent,
                            "offset": "\(fileSend.sentSize)",
                            "total": "\(fileSend.totalSize!)"
            ])
        _send(data: data) { [weak self] () in
            guard let self = self else { return }
            
            task.completionHandler?()
            
            var fileSend = self.fileSends[id]!
            fileSend.sentSize += sendSize
            if fileSend.sentSize < fileSend.totalSize! {
                self.update(fileSend: fileSend)
                
                let task = SendTask(content: .file(id: fileSend.id),
                                    completionHandler: nil)
                self.sendQueue.append(task)
            } else {
                self.fileSends.removeValue(forKey: id)
            }
        }
    }
    
    private func update(fileSend: FileSend) {
        fileSends[fileSend.id.id] = fileSend
    }
    
    private func build(body: Data,
                       fields: [String: String]) -> Data
    {
        var fields = fields
        fields["length"] = "\(body.count)"
        var header = fields
            .map { (k, v) in "\(k)=\(v)" }
            .joined(separator: "\n")
        header += "\n\n"
        let data = header.data(using: .utf8)! + body
        return data
    }
    
    private func _send(data: Data,
                       completionHandler: @escaping () throws -> Void)
    {
        precondition(!isSending)
        isSending = true
        connection.send(content: data,
                        contentContext: .defaultStream,
                        isComplete: false,
                        completion: .contentProcessed({ [weak self] (error) in
                            guard let self = self else {
                                return
                            }
                            self.isSending = false
                            
                            do {
                                if let error = error {
                                    throw error
                                }
                                
                                try completionHandler()
                                
                                self.driveSending()
                            } catch {
                                self.emitError(error)
                            }
                        }))
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 1024)
        { [weak self] (data, context, isFinished, error) in
            
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
        close()
        
        errorHandler?(error)
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
