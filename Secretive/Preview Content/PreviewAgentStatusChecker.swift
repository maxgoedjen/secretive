import Foundation
import Combine

class PreviewAgentStatusChecker: AgentStatusCheckerProtocol {

    let running: Bool

    init(running: Bool = true) {
        self.running = running
    }

}
