import Foundation
import AppKit

class PreviewAgentLaunchController: AgentLaunchControllerProtocol {

    let running: Bool
    let process: NSRunningApplication?
    let developmentBuild = false

    init(running: Bool = true, process: NSRunningApplication? = nil) {
        self.running = running
        self.process = process
    }

    func check() {
    }

    func install() async throws {
    }

    func uninstall() async throws {
    }

    func forceLaunch() async throws {
    }

}
