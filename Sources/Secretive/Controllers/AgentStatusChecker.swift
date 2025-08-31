import Foundation
import AppKit
import SecretKit
import Observation

@MainActor protocol AgentStatusCheckerProtocol: Observable, Sendable {
    var running: Bool { get }
    var developmentBuild: Bool { get }
    var process: NSRunningApplication? { get }
    func check()
}

@Observable @MainActor final class AgentStatusChecker: AgentStatusCheckerProtocol {

    var running: Bool = false
    var process: NSRunningApplication? = nil

    nonisolated init() {
        Task { @MainActor in
            check()
        }
    }

    func check() {
        process = instanceSecretAgentProcess
        running = process != nil
    }

    // All processes, including ones from older versions, etc
    var allSecretAgentProcesses: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.agentBundleID)
    }

    // The process corresponding to this instance of Secretive
    var instanceSecretAgentProcess: NSRunningApplication? {
        // FIXME: CHECK VERSION
        let agents = allSecretAgentProcesses
        for agent in agents {
            guard let url = agent.bundleURL else { continue }
            if url.absoluteString.hasPrefix(Bundle.main.bundleURL.absoluteString) || (url.isXcodeURL && developmentBuild) {
                return agent
            }
        }
        return nil
    }

    // Whether Secretive is being run in an Xcode environment.
    var developmentBuild: Bool {
        Bundle.main.bundleURL.isXcodeURL
    }

}

extension URL {

    var isXcodeURL: Bool {
        absoluteString.contains("/Library/Developer/Xcode")
    }

}
