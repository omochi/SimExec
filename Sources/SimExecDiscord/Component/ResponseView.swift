import Foundation
import SimExec
import SwiftDiscord

public final class ResponseView {
    private let discord: DiscordClient
    public let channel: DiscordChannel
    
    private var isNetworking: Bool
    
    private var isDirty: Bool
    private var messageID: MessageID?
    
    public var message: String? {
        didSet {
            isDirty = true
            update()
        }
    }
    
    public init(discord: DiscordClient,
                channel: DiscordChannel)
    {
        self.discord = discord
        self.channel = channel
        self.isNetworking = false
        self.isDirty = false
    }
    
    public func reset() {
        messageID = nil
    }
    
    private func update() {
        if !isDirty {
            return
        }
        
        if isNetworking {
            return
        }
        
        if let messageID = self.messageID {
            if let message = self.message {
                isDirty = false
                isNetworking = true
                
                discord.editMessage(messageID, on: channel.id, content: message)
                { [self] (message, response) in
                    self.isNetworking = false
                    defer { self.update() }
                    
                    self.messageID = message?.id
                }
            } else {
                isDirty = false
                isNetworking = true
                
                discord.deleteMessage(messageID, on: channel.id)
                { [self] (ok, response) in
                    self.isNetworking = false
                    defer { self.update() }
                    
                    self.messageID = nil
                }
            }
        } else {
            if let message = self.message {
                isDirty = false
                isNetworking = true
                
                discord.sendMessage(DiscordMessage(content: message),
                                    to: channel.id)
                { [self] (message, response) in
                    self.isNetworking = false
                    defer { self.update() }
                    
                    self.messageID = message?.id
                }
            }
        }
    }
}
