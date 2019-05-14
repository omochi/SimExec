import XCTest
import SimExec

//private let udid = "F16240A8-B724-4724-AB34-3D54F9EE1B90"
private let udid = "0C737A0A-2CFB-45FC-9A41-70155C98460D"

final class SimExecTests: XCTestCase {
    var fs: FileSystem!
    
    override func setUp() {
        fs = FileSystem(applicationName: "SimExecTests")
    }
    
    override func tearDown() {
        fs.deleteKeepedTemporaryFiles()
    }
    
    func testSuccess() throws {
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
    
    func testBuildFailure() throws {
        let sourceFile = try fs.makeTemporaryDirectory(name: "source", deleteAfter: true)
            .appendingPathComponent("source.swift")
        
        let source = """
import UIKit
class ViewController : UIViewController {
    override func viewDidFooBar() {
        super.viewDidLoad()
    }
}
"""
        try source.data(using: .utf8)!.write(to: sourceFile)
        
        let options = SimExecTool.Options(sourceFile: sourceFile,
                                          simulatorDeviceUDID: udid,
                                          keepTemporaryFiles: true)
        let tool = SimExecTool(options: options)
        do {
            try tool.run()
            XCTFail("broken code passed")
        } catch {
            switch error {
            case let e as Xcodebuild.BuildError:
                let str = e.out.toUTF8Robust()
                XCTAssertTrue(str.contains("viewDidFooBar"))
            default:
                XCTFail("invalid error type")
            }
        }
    }
}
