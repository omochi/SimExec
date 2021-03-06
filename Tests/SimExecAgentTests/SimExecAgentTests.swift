import XCTest
import SimExec
import SimExecAgent

//private let udid = "F16240A8-B724-4724-AB34-3D54F9EE1B90"
private let udid = "0C737A0A-2CFB-45FC-9A41-70155C98460D"

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
    
    func testFirstState() throws {
        let exp = expectation(description: "")

        let client = SimExecAgentClient(host: "localhost",
                                        queue: .main)
        
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
    
    func testFullSuccess() throws {
        let exp = expectation(description: "")
        
        let client = SimExecAgentClient(host: "localhost",
                                        queue: .main)
        
        client.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        client.start()
        
        var stateIndex = 0
        client.stateHandler = { (state) in
            switch stateIndex {
            case 0: XCTAssertEqual(state, .ready)
            case 1: XCTAssertEqual(state, .start)
            case 2: XCTAssertEqual(state, .build)
            case 3: XCTAssertEqual(state, .launch)
            case 4: XCTAssertEqual(state, .running)
            case 5: XCTAssertEqual(state, .ready)
            default: break
            }
            stateIndex += 1
        }
        
        client.screenshotHandler = { (file) in
            guard let image = NSImage(contentsOf: file) else {
                XCTFail("broken image")
                return
            }
            print(image.size)
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
        
        wait(for: [exp], timeout: 300)
    }
    
    func testBuildFailure() {
        let exp = expectation(description: "")
        
        let client = SimExecAgentClient(host: "localhost", queue: .main)
        
        client.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        client.start()
        
        var stateIndex = 0
        client.stateHandler = { (state) in
            switch stateIndex {
            case 0: XCTAssertEqual(state, .ready)
            case 1: XCTAssertEqual(state, .start)
            case 2: XCTAssertEqual(state, .build)
            case 3: XCTAssertEqual(state, .ready)
            default: break
            }
            stateIndex += 1
        }
        
        let source = """
import UIKit
class ViewController : UIViewController {
    override func viewDidFooBar() {
        super.viewDidLoad()
    }
}
"""
        
        client.request(SimExecAgentTool.Request(source: source,
                                                udid: udid))
        { (response) in
            do {
                _ = try response.get()
                XCTFail("broken source passed")
            } catch {
                
                XCTAssertEqual(stateIndex, 4)

                let str = "\(error)"
                XCTAssertTrue(str.contains("viewDidFooBar"))

                exp.fulfill()
            }
        }
        
        wait(for: [exp], timeout: 300)
    }
    
    func testConflictClients() {
        var startClient2: (() -> Void)!
        
        let exp = expectation(description: "")
        
        let client = SimExecAgentClient(host: "localhost", queue: .main)
        client.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        client.start()
        
        let client2 = SimExecAgentClient(host: "localhost", queue: .main)
        client2.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        var stateIndex = 0
        client.stateHandler = { (state) in
            switch stateIndex {
            case 0: XCTAssertEqual(state, .ready)
            case 1:
                XCTAssertEqual(state, .start)
                
                startClient2()
            default: break
            }
            stateIndex += 1
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

        startClient2 = {
            client2.start()
            client2.request(SimExecAgentTool.Request(source: source,
                                                     udid: udid))
            { (response) in
                do {
                    _ = try response.get()
                    XCTFail("double request accepted")
                } catch {
                    let str = "\(error)"
                    XCTAssertTrue(str.contains("not ready"))
                }
            }
        }
        
        wait(for: [exp], timeout: 300)
    }
}
