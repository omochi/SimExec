import Foundation
import SimExec
import Sword

public final class SimExecDiscordTool {
    private let queue: DispatchQueue
    private let discord: Sword
    
    public init(queue: DispatchQueue) throws {
        self.queue = queue
        
        let env = ProcessInfo.processInfo.environment
        guard let token = env["DISCORD_TOKEN"], !token.isEmpty else {
            throw MessageError("no DISCORD_TOKEN")
        }
        
        var options = Options()
        options.logging = true
        options.transportCompression = false
        discord = Sword(token: token, options: options)

        discord.on.guildAvailable = { [weak self] (guild) in
            guard let self = self else {
                return
            }

            print(guild)
        }
        discord.on.ready = { [weak self] (user) in
            guard let self = self else {
                return
            }
            
            print(user)
        }
        discord.connect()
    }
    
    deinit {
        print("deinit")
    }
    
    public static func main(arguments: [String]) {
        do {
            let tool = try SimExecDiscordTool(queue: DispatchQueue.main)
            _ = tool
            dispatchMain()
        } catch {
            fatalError("\(error)")
        }
    }
}
