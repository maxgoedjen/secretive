import Foundation
import ServiceManagement
import AppKit
import OSLog

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
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { app, error in
            completion?(error == nil)
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
