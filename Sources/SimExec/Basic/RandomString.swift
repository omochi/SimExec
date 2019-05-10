import Foundation

private let randomStringCharacters: [Character] = {
    let str = [
        "abcdefghijklmnopqrstuvwxyz",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "0123456789"
    ].joined()
    return str.map { $0 }
}()

public func randomString(length: Int) -> String {
    let chars = randomStringCharacters
    var s = ""
    for _ in 0..<length {
        let char = chars.randomElement()!
        s.append(char)
    }
    return s
}
