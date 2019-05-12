import XCTest
import SimExec
import SimExecAgent

final class SimExecAgentTests: XCTestCase {
    var fs: FileSystem!
    
    override func setUp() {
        fs = FileSystem(applicationName: "SimExecAgentTests")
    }
    
    override func tearDown() {
        fs.deleteKeepedTemporaryFiles()
    }
    
    func test1() throws {
        let tool = SimExecAgentTool()
        tool.start()
    }
}
