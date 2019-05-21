import Foundation

public struct ControlMessage {
    
    public var code: String
    
    public init(code: String) {
        self.code = code
    }
    
    public static func parse(_ message: String) -> ControlMessage? {
        let quote = "```"
        
        guard let quoteRange0 = message.range(of: quote) else {
            return nil
        }
        guard let quoteRange1 = message.range(of: quote, options: [],
                                              range: (quoteRange0.upperBound...).relative(to: message),
                                              locale: nil) else
        {
            return nil
        }
        
        var code = String(message[quoteRange0.upperBound..<quoteRange1.lowerBound])
        code = code.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return ControlMessage(code: code)
    }
}
