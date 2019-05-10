import Foundation

extension FileManager {
    public func fileExists(at url: URL) -> Bool {
        return fileExists(atPath: url.path)
    }
    
    public func fileExists(at url: URL, isDirectory: inout Bool) -> Bool {
        var isDir = ObjCBool(false)
        let ret = fileExists(atPath: url.path,
                             isDirectory: &isDir)
        isDirectory = isDir.boolValue
        return ret
    }
    
    public func copyItem(at srcURL: URL, to dstURL: URL, overwrite: Bool) throws {
        if overwrite, fileExists(at: dstURL) {
            try removeItem(at: dstURL)
        }
        try copyItem(at: srcURL, to: dstURL)
    }
    
    public func changeCurrentDirectory(to url: URL) throws {
        guard changeCurrentDirectoryPath(url.path) else {
            throw MessageError("change directory failed: \(url.path)")
        }
    }
}
