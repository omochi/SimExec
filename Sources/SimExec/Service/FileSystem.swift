import Foundation

internal let fm = FileManager.default

public final class FileSystem {
    private let applicationName: String
    
    private var keepedTemporaryFiles: [URL] = []

    public init(applicationName: String) {
        self.applicationName = applicationName
    }
    
    public func makeTemporaryDirectory(name: String, deleteAfter: Bool) throws -> URL {
        let path = try makeTemporaryPath(name: name, deleteAfter: deleteAfter)
        try fm.createDirectory(at: path, withIntermediateDirectories: true)
        return path
    }
    
    public func makeTemporaryPath(name: String, deleteAfter: Bool) throws -> URL {
        let tempRootDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(applicationName)
        while true {
            let pathName = "\(name).\(randomString(length: 8))"
            let path = tempRootDir.appendingPathComponent(pathName)
            if fm.fileExists(at: path) {
                continue
            }
            if deleteAfter {
                keepedTemporaryFiles.append(path)
            }
            return path
        }
    }
    
    public func deleteKeepedTemporaryFiles() {
        for d in keepedTemporaryFiles {
            _ = try? fm.removeItem(at: d)
        }
        keepedTemporaryFiles = []
    }
}
