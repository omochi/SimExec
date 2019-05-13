import XCTest
import SimExec

private let udid = "F16240A8-B724-4724-AB34-3D54F9EE1B90"

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
        view.backgroundColor = UIColor.green
        fputs("stdout\\n", stdout)
        fflush(stdout)
        fputs("stderr\\n", stderr)
        fflush(stderr)
    }
}
"""
        try source.data(using: .utf8)!.write(to: sourceFile)
        
        let options = SimExecTool.Options(sourceFile: sourceFile,
                                          simulatorDeviceUDID: udid,
                                          keepTemporaryFiles: true)
        let tool = SimExecTool(options: options)
        try tool.run()
    }
}
