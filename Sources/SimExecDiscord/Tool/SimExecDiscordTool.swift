import Foundation
import SimExec
import Sword

public final class SimExecDiscordTool {
    private let queue: DispatchQueue
    
    public init(queue: DispatchQueue) throws {
        self.queue = queue
        
        let env = ProcessInfo.processInfo.environment
        guard let token = env["DISCORD_TOKEN"], !token.isEmpty else {
            throw MessageError("no DISCORD_TOKEN")
        }
        
        
    }
    
    public static func main(arguments: [String]) {
        do {
            _ = try SimExecDiscordTool(queue: DispatchQueue.main)
            dispatchMain()
        } catch {
            fatalError("\(error)")
        }
    }
}
