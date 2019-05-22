import Foundation
import AppKit
import SimExec
import SimExecAgent
import SwiftDiscord

public final class SimExecDiscordTool : DiscordClientDelegate {
    private let queue: DispatchQueue
    private var discord: DiscordClient!
    
    private var simulatorUDID: String!
    
    private var simExec: SimExecAgentClient?
    
    private var requestedChannel: DiscordTextChannel?
    private var responseView: ResponseView?
    
    public init(queue: DispatchQueue) throws {
        self.queue = queue
        
        let env = ProcessInfo.processInfo.environment
        guard let token = env["DISCORD_TOKEN"], !token.isEmpty else {
            throw MessageError("no DISCORD_TOKEN")
        }
        
        guard let udid = env["SIM_UDID"], !udid.isEmpty else {
            throw MessageError("no SIM_UDID")
        }
        self.simulatorUDID = udid
        
        
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
        
        if let _ = self.simExec {
            sendBusyImmediately(channelID: channel.id)
            return
        }
        
        self.requestedChannel = channel
        self.responseView = ResponseView(discord: discord, channel: channel)
        
        do {
            try cm.validate()
        } catch {
            self.responseView?.message = "\(error)"
            reset()
            return
        }

        let simExec = SimExecAgentClient(host: "localhost", queue: queue)
        self.simExec = simExec
        
        simExec.errorHandler = { [weak self] (error) in
            self?.handleSimExecError(error)
        }
        
        simExec.screenshotHandler = { [weak self] (file) in
            guard let self = self,
                let cid = self.responseView?.channel.id else { return }
            
            do {
                let data = try Data(contentsOf: file)
                
                let filename = file.lastPathComponent
                let upload = DiscordFileUpload(data: data,
                                               filename: filename,
                                               mimeType: "image/png")
                let message = DiscordMessage(content: filename,
                                             embed: nil,
                                             files: [upload],
                                             tts: false)
                self.discord.sendMessage(message, to: cid)
                
                self.responseView?.reset()
            } catch {
                print("ss failure: \(error)")
            }
        }
        
        simExec.stateHandler = { [weak self] (state) in
            guard let self = self else { return }
            
            switch state {
            case .ready: break
            case .start:
                self.updateResponse(message: "準備中・・・")
            case .build:
                self.updateResponse(message: "ビルド中・・・")
            case .launch:
                self.updateResponse(message: "起動中・・・")
            case .running:
                self.updateResponse(message: "実行中・・・")
            }
        }

        simExec.start()
        
        simExec.request(SimExecAgentTool.Request(source: cm.code,
                                                 udid: simulatorUDID))
        { [weak self] (response) in
            guard let self = self else { return }
            do {
                let response = try response.get()
                
                let msg = "標準出力:\n\(response.out)"
                self.updateResponse(message: msg)
                self.reset()
            } catch {
                self.handleSimExecError(error)
            }
        }
    }
    
    private func sendBusyImmediately(channelID: ChannelID) {
        sendResponseImmediately(message: "今忙しいのでまた後にしてください。",
                                channelID: channelID)
    }
    
    private func sendResponseImmediately(message: String, channelID: ChannelID?) {
        guard let cid = channelID ?? requestedChannel?.id else { return }
        discord.sendMessage(DiscordMessage(content: message), to: cid)
    }
    
    private func handleSimExecError(_ error: Error) {
        defer {
            reset()
        }

        let msg = "問題が発生しました:\n\(error)"
        updateResponse(message: msg)
    }
    
    private func updateResponse(message: String) {
        responseView?.message = message
    }
    
    private func reset() {
        simExec = nil
        requestedChannel = nil
        responseView = nil
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
