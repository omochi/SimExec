import Foundation
import SimExec
import SimExecAgent
import SwiftDiscord

public final class SimExecDiscordTool : DiscordClientDelegate {
    private let queue: DispatchQueue
    private var discord: DiscordClient!
    
    private var requestedChannel: DiscordTextChannel?
    private var simExec: SimExecAgentClient?
    
    public init(queue: DispatchQueue) throws {
        self.queue = queue
        
        let env = ProcessInfo.processInfo.environment
        guard let token = env["DISCORD_TOKEN"], !token.isEmpty else {
            throw MessageError("no DISCORD_TOKEN")
        }
        
        discord = DiscordClient(token: DiscordToken(stringLiteral: "Bot " + token),
                                delegate: self)
        discord.handleQueue = queue
        
        discord.connect()
    }
    
    deinit {
        print("deinit")
    }
    
    public func client(_ client: DiscordClient, didConnect connected: Bool) {
//        let game = DiscordActivity(name: "xxx", type: DiscordActivityType.game)
        client.setPresence(DiscordPresenceUpdate(game: nil))
//        client.user?.
    }
    
    public func client(_ client: DiscordClient, didCreateMessage message: DiscordMessage) {
        guard let botUser = client.user,
            let channel = message.channel,
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
        
        if let simExec = self.simExec {
            if let ch = requestedChannel {
                sendBusy(channel: ch)
            }
            return
        }

        self.requestedChannel = channel

        let simExec = SimExecAgentClient(host: "localhost", queue: queue)
        self.simExec = simExec
        
        simExec.errorHandler = { [weak self] (error) in
            self?.handleRequestError(error)
        }

        simExec.start()
    }
    
    private func sendBusy(channel: DiscordTextChannel) {
        channel.send("今忙しいのでまた後で来てください。")
    }
    
    private func handleRequestError(_ error: Error) {
        defer {
            reset()
        }
        
        guard let ch = requestedChannel else {
            return
        }
        
        let msg = "\(error)"
        ch.send(DiscordMessage(content: msg))
    }
    
    private func reset() {
        simExec = nil
        requestedChannel = nil
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
