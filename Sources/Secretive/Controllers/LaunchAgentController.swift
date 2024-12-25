import Foundation
import ServiceManagement
import AppKit
import OSLog
import SecretKit

struct LaunchAgentController {
    
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive", category: "LaunchAgentController")

    func install() async {
        logger.debug("Installing agent")
        _ = setEnabled(false)
        // This is definitely a bit of a "seems to work better" thing but:
        // Seems to more reliably hit if these are on separate runloops, otherwise it seems like it sometimes doesn't kill old
        // and start new?
        try? await Task.sleep(for: .seconds(1))
        await MainActor.run {
            _  = setEnabled(true)
        }
    }

    func forceLaunch() async -> Bool {
        logger.debug("Agent is not running, attempting to force launch")
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        do {
            let app = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            logger.debug("Agent force launched")
            return true
        } catch {
            logger.error("Error force launching \(error.localizedDescription)")
            return false
        }
    }

    private func setEnabled(_ enabled: Bool) -> Bool {
        // FIXME: THIS
        SMLoginItemSetEnabled(Bundle.main.agentBundleID as CFString, enabled)
    }

}
