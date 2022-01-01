import Foundation
import Combine

class PreviewAgentStatusChecker: AgentStatusCheckerProtocol {

    let running: Bool
    let developmentBuild = false

    init(running: Bool = true) {
        self.running = running
    }

}
