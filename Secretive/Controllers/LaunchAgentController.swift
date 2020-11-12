import Foundation
import ServiceManagement
import AppKit
import OSLog

struct LaunchAgentController {

    func install() -> Bool {
        Logger().debug("Installing agent")
        _ = setEnabled(false)
        return setEnabled(true)
    }

    func forceLaunch() {
        Logger().debug("Agent is not running, attempting to force launch")
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
            if let error = error {
                Logger().error("Error force launching \(error.localizedDescription)")
            } else {
                Logger().debug("Agent force launched")
            }
        }
    }

    private func setEnabled(_ enabled: Bool) -> Bool {
        SMLoginItemSetEnabled("com.maxgoedjen.Secretive.SecretAgent" as CFString, enabled)
    }

}
