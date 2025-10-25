import Foundation
import AppKit
import SecretKit
import Observation
import OSLog
import ServiceManagement

@MainActor protocol AgentLaunchControllerProtocol: Observable, Sendable {
    var running: Bool { get }
    var developmentBuild: Bool { get }
    var process: NSRunningApplication? { get }
    func check()
    func install() async throws
    func uninstall() async throws
    func forceLaunch() async throws
}

@Observable @MainActor final class AgentLaunchController: AgentLaunchControllerProtocol {

    var running: Bool = false
    var process: NSRunningApplication? = nil
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive", category: "LaunchAgentController")
    private let service = SMAppService.loginItem(identifier: Bundle.agentBundleID)

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
        // TODO: CHECK VERSION
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

    func install() async throws {
        logger.debug("Installing agent")
        try? await service.unregister()
        // This is definitely a bit of a "seems to work better" thing but:
        // Seems to more reliably hit if these are on separate runloops, otherwise it seems like it sometimes doesn't kill old
        // and start new?
        try await Task.sleep(for: .seconds(1))
        try service.register()
        try await Task.sleep(for: .seconds(1))
        check()
    }

    func uninstall() async throws {
        logger.debug("Uninstalling agent")
        try await Task.sleep(for: .seconds(1))
        try await service.unregister()
        try await Task.sleep(for: .seconds(1))
        check()
    }

    func forceLaunch() async throws {
        logger.debug("Agent is not running, attempting to force launch by reinstalling")
        try await install()
        if running {
            logger.debug("Agent successfully force launched by reinstalling")
            return
        }
        logger.debug("Agent is not running, attempting to force launch by launching directly")
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            logger.debug("Agent force launched")
            try await Task.sleep(for: .seconds(1))
        } catch {
            logger.error("Error force launching \(error.localizedDescription)")
        }
        check()
    }

}

extension URL {

    var isXcodeURL: Bool {
        absoluteString.contains("/Library/Developer/Xcode")
    }

}
