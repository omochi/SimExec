import Foundation

extension Pipe {
    public static func output(_ handler: @escaping (Data) -> Void) -> Pipe {
        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { (h) in
            let chunk = h.availableData
            handler(chunk)
        }
        return pipe
    }
}
