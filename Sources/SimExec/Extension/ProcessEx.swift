import Foundation

public struct ExitStatusError : ErrorBase {
    public var executable: URL
    public var arguments: [String]
    public var status: Int32
    public var error: Data?
    
    public var description: String {
        var m = [
            "exit status=\(status)",
            "command=\(executable.path)",
            "arguments=\(arguments)"
        ]
        if let error = error {
            m.append("error=\(error.toUTF8Robust())")
        }
        return m.joined(separator: ", ")
    }
}

extension Process {
    public func exitStatusError(errorData: Data?) -> ExitStatusError {
        return ExitStatusError(executable: executableURL!,
                               arguments: arguments!,
                               status: terminationStatus,
                               error: errorData)
    }
}
