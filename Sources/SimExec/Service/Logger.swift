import Foundation
import os.log

public final class Logger {
    private let tag: String
    
    public init(tag: String) {
        self.tag = tag
    }
    
    public func debug(_ message: String) {
        log(type: .debug, message: message)
    }
    
    public func critical(_ message: String) {
        log(type: .fault, message: message)
    }
    
    private func log(type: OSLogType, message: String) {
        os_log(type, "[%@] %@", tag, message)
    }
    
}
