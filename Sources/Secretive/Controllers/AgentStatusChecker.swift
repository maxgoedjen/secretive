import Foundation
import Combine
import AppKit
import SecretKit

protocol AgentStatusCheckerProtocol: ObservableObject {
    var running: Bool { get }
}

class AgentStatusChecker: ObservableObject, AgentStatusCheckerProtocol {

    @Published var running: Bool = false

    init() {
        check()
    }

    func check() {
        running = instanceSecretAgentProcess != nil
    }

    // All processes, including ones from older versions, etc
    var secretAgentProcesses: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.agentBundleID)
    }

    // The process corresponding to this instance of Secretive
    var instanceSecretAgentProcess: NSRunningApplication? {
        let agents = secretAgentProcesses
        for agent in agents {
            guard let url = agent.bundleURL else { continue }
            if url.absoluteString.hasPrefix(Bundle.main.bundleURL.absoluteString) {
                return agent
            }
        }
        return nil
    }

}


