import Foundation
import AppKit
import SecretKit
import Observation

@MainActor protocol AgentStatusCheckerProtocol: Observable, Sendable {
    var running: Bool { get }
    var developmentBuild: Bool { get }
    func check()
}

@Observable @MainActor final class AgentStatusChecker: AgentStatusCheckerProtocol {

    var running: Bool = false

    nonisolated init() {
        Task { @MainActor in
            check()
        }
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


    // Whether Secretive is being run in an Xcode environment.
    var developmentBuild: Bool {
        Bundle.main.bundleURL.absoluteString.contains("/Library/Developer/Xcode")
    }

}


