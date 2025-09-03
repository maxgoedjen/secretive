import Foundation
import AppKit

class PreviewAgentStatusChecker: AgentStatusCheckerProtocol {

    let running: Bool
    let process: NSRunningApplication?
    let developmentBuild = false

    init(running: Bool = true, process: NSRunningApplication? = nil) {
        self.running = running
        self.process = process
    }

    func check() {
    }

}
