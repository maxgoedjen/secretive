import Foundation
import Combine
import AppKit
import SecretKit

protocol AgentStatusCheckerProtocol: ObservableObject {
    var running: Bool { get }
    var developmentBuild: Bool { get }
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
            if url.absoluteString.contains(Bundle.main.bundleURL.absoluteString) {
                return agent
            }
        }
        return nil
    }

    // All processes, _NOT_ including one the instance agent.
    var noninstanceSecretAgentProcesses: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.agentBundleID)
            .filter({ !($0.bundleURL?.absoluteString.contains(Bundle.main.bundleURL.absoluteString) ?? false) })
    }

    // Whether Secretive is being run in an Xcode environment.
    var developmentBuild: Bool {
        Bundle.main.bundleURL.absoluteString.contains("/Library/Developer/Xcode")
    }

}


