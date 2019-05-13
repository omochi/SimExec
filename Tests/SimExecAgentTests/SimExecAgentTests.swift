import XCTest
import SimExec
import SimExecAgent

final class SimExecAgentTests: XCTestCase {
    var agent: SimExecAgentTool?
    
    func test1() throws {
        let exp = expectation(description: "")
        
        let agent = try SimExecAgentTool(queue: DispatchQueue.main)
        self.agent = agent
        
        let client = SimExecAgentClient(host: "localhost", queue: DispatchQueue.main)
        
        client.errorHandler = { (error) in
            XCTFail("\(error)")
        }
        
        client.start()
        
        client.state { (state) in
            do {
                let state = try state.get()
                XCTAssertEqual(state, SimExecAgentTool.State.ready)
                exp.fulfill()
            } catch {
                XCTFail("\(error)")
            }
        }
        
        wait(for: [exp], timeout: 10)
    }
}
