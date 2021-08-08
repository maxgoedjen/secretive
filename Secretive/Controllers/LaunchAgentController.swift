import Foundation
import ServiceManagement
import AppKit
import OSLog
import SecretKit

struct LaunchAgentController {
    
    func install(completion: (() -> Void)? = nil) {
        Logger().debug("Installing agent")
        _ = setEnabled(false)
        // This is definitely a bit of a "seems to work better" thing but:
        // Seems to more reliably hit if these are on separate runloops, otherwise it seems like it sometimes doesn't kill old
        // and start new?
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            _  = setEnabled(true)
            completion?()
        }

    }

    func forceLaunch(completion: ((Bool) -> Void)?) {
        Logger().debug("Agent is not running, attempting to force launch")
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, error in
            DispatchQueue.main.async {
                completion?(error == nil)
            }
            if let error = error {
                Logger().error("Error force launching \(error.localizedDescription)")
            } else {
                Logger().debug("Agent force launched")
            }
        }
    }

    private func setEnabled(_ enabled: Bool) -> Bool {
        SMLoginItemSetEnabled(Bundle.main.agentBundleID as CFString, enabled)
    }

}
