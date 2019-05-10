import XCTest
import SimExec

final class SimExecTests: XCTestCase {
    var fs: FileSystem!
    
    override func setUp() {
        fs = FileSystem(applicationName: "SimExecTests")
    }
    
    override func tearDown() {
        fs.deleteKeepedTemporaryFiles()
    }
    
    func test1() throws {
        let sourceFile = try fs.makeTemporaryDirectory(name: "source", deleteAfter: true)
            .appendingPathComponent("source.swift")
        
        let source = """
import UIKit
class ViewController : UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.blue
        fputs("stdout", stdout)
        fputs("stderr", stderr)
    }
}
"""
        try source.data(using: .utf8)!.write(to: sourceFile)
        
        let args = [
            "sim-exec",
            "--source", sourceFile.path,
            "--device", "F16240A8-B724-4724-AB34-3D54F9EE1B90",
            "--keep-temps"
        ]
        try SimExecTool.main(args: args)
    }
    
    func test2() throws {
        let res = try Simctl.list()
        dump(res)
    }
}
