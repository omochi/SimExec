import Foundation

public final class SimExecAgentSocketAdapter {
    private let agent: SimExecAgentTool
    
    public init(agent: SimExecAgentTool) throws {
        self.agent = agent
    }
}
