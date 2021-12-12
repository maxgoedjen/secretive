import Foundation
import ServiceManagement
import AppKit
import OSLog
import SecretKit

struct LaunchAgentController {

    private let logger = Logger()
    
    func install() async {
        logger.debug("Installing agent")
        _ = setEnabled(false)
        // This is definitely a bit of a "seems to work better" thing but:
        // Seems to more reliably hit if these are on separate runloops, otherwise it seems like it sometimes doesn't kill old
        // and start new?
        try? await Task.sleep(nanoseconds: UInt64(Measurement(value: 0.1, unit: UnitDuration.seconds).converted(to: .nanoseconds).value))
        _  = setEnabled(true)
    }

    func forceLaunch() async throws {
        logger.debug("Agent is not running, attempting to force launch")
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: config)
            logger.debug("Agent force launched")
        } catch {
            logger.error("Error force launching \(error.localizedDescription)")
            throw error
        }
    }

    private func setEnabled(_ enabled: Bool) -> Bool {
        SMLoginItemSetEnabled(Bundle.main.agentBundleID as CFString, enabled)
    }

}
