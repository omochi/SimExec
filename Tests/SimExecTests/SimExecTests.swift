import XCTest
import SimExec

final class SimExecTests: XCTestCase {
    func test1() throws {
        let args = [
            "sim-exec",
            "--source", "source.swift",
            "--device", "0C737A0A-2CFB-45FC-9A41-70155C98460D"
        ]
        try SimExecTool.main(args: args)
    }
}
