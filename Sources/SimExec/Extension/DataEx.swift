import Foundation

extension Data {
    public func toUTF8() throws -> String {
        if let str = String(data: self, encoding: .utf8) {
            return str
        }
        throw MessageError("UTF-8 decode failed")
    }
    
    public func toUTF8Robust() -> String {
        var data = self
        data.append(0)
        let (str, _) = data.withUnsafeBytes {
            (bufPtr: UnsafeRawBufferPointer) -> (result: String, repairsMade: Bool) in
            let ptr = bufPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return String.decodeCString(ptr,
                                        as: Unicode.UTF8.self,
                                        repairingInvalidCodeUnits: true)!
        }
        return str
    }
}
