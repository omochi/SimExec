import XCTest
import SimExec
import SimExecAgent

final class SimExecAgentTests: XCTestCase {
    var agent: SimExecAgentTool?
    
    override func setUp() {
        let agent = try! SimExecAgentTool(queue: .main)
        self.agent = agent
    }
    
    override func tearDown() {
        agent?.terminate()
        agent = nil
    }
    
    func test1() throws {
        let exp = expectation(description: "")

        let client = SimExecAgentClient(host: "localhost", queue: .main)
        
        client.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        client.start()
        
        client.stateHandler = { (state) in
            XCTAssertEqual(state, SimExecAgentTool.State.ready)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 10)
    }
    
    func test2() throws {
        let exp = expectation(description: "")
        
        let client = SimExecAgentClient(host: "localhost", queue: .main)
        
        client.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        client.start()
        
        var i = 0
        client.stateHandler = { (state) in
            switch i {
            case 0: XCTAssertEqual(state, .ready)
            case 1: XCTAssertEqual(state, .start)
            case 2: XCTAssertEqual(state, .build)
            case 3: XCTAssertEqual(state, .launch)
            case 4: XCTAssertEqual(state, .running)
            case 5: XCTAssertEqual(state, .ready)
            default: break
            }
            i += 1
        }
        
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
        
        let udid = "F16240A8-B724-4724-AB34-3D54F9EE1B90"
        client.request(SimExecAgentTool.Request(source: source,
                                                udid: udid))
        { (response) in
            do {
                let response = try response.get()
                XCTAssertEqual(response.out, "stdout\n")
                XCTAssertEqual(response.error, "stderr\n")
                exp.fulfill()
            } catch {
                XCTFail("\(error)")
            }
        }
        
        wait(for: [exp], timeout: 60)
    }
}
