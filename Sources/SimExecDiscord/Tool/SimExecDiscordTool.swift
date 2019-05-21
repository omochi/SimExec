import Foundation
import SimExec
import SimExecAgent
import SwiftDiscord

public final class SimExecDiscordTool : DiscordClientDelegate {
    private let queue: DispatchQueue
    private var discord: DiscordClient!
    
    private var simExec: SimExecAgentClient?
    
    public init(queue: DispatchQueue) throws {
        self.queue = queue
        
        let env = ProcessInfo.processInfo.environment
        guard let token = env["DISCORD_TOKEN"], !token.isEmpty else {
            throw MessageError("no DISCORD_TOKEN")
        }
        
        discord = DiscordClient(token: DiscordToken(stringLiteral: token),
                                delegate: self)
        discord.handleQueue = queue
        
        discord.connect()
    }
    
    deinit {
        print("deinit")
    }
    
    public func client(_ client: DiscordClient, didCreateMessage message: DiscordMessage) {
        guard let botUser = client.user,
            !message.author.bot,
            !message.mentionEveryone,
            !message.pinned,
            (message.mentions.contains { $0.id == botUser.id }) else
        {
            return
        }
        
        guard let cm = ControlMessage.parse(message.content) else {
            return
        }
        
        print(cm.code)
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
