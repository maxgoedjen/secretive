import Foundation
import Combine
import AppKit

protocol AgentStatusCheckerProtocol: ObservableObject {
    var running: Bool { get }
}

class AgentStatusChecker: ObservableObject, AgentStatusCheckerProtocol {

    @Published var running: Bool = false

    init() {
        check()
    }

    func check() {
        running = secretAgentProcess != nil
    }

    var secretAgentProcess: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Constants.secretAgentAppID).first
    }

}

extension AgentStatusChecker {

    enum Constants {
        static let secretAgentAppID = "com.maxgoedjen.Secretive.SecretAgent"
    }

}
