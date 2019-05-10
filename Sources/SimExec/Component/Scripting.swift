import Foundation

public func findCommand(_ command: String) throws -> URL {
    if (command as NSString).isAbsolutePath {
        return URL(fileURLWithPath: command)
    }
    
    let args = ["/usr/bin/which", command]
    guard let strData = try? capture(arguments: args) else {
        throw MessageError("command not found: \(command)")
    }
    var str = try strData.toUTF8()
    str = str.trimmingCharacters(in: .whitespacesAndNewlines)
    precondition((str as NSString).isAbsolutePath)
    return URL(fileURLWithPath: str)
}

public func system(arguments: [String]) throws
{
    let p = try runProcess(arguments: arguments)
    guard p.terminationStatus == EXIT_SUCCESS else {
        throw p.exitStatusError(errorData: nil)
    }
}

public func capture(arguments: [String]) throws -> Data
{
    var out = Data()
    var error = Data()
    let p = try runProcess(arguments: arguments,
                           out: Pipe.output { (d) in
                            out.append(d) },
                           error: Pipe.output { (d) in
                            error.append(d) })
    guard p.terminationStatus == EXIT_SUCCESS else {
        throw p.exitStatusError(errorData: error)
    }
    return out
}

public func runProcess(arguments: [String],
                       out: Any? = nil,
                       error: Any? = nil)
    throws -> Process
{
    let p = Process()
    p.executableURL = try findCommand(arguments[0])
    p.arguments = arguments[1...].map { $0 }
    p.standardOutput = out
    p.standardError = error
    try p.run()
    p.waitUntilExit()
    return p
}
