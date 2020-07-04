import Foundation
import ServiceManagement

struct LaunchAgentController {

    func install() -> Bool {
        setEnabled(true)
    }

    func relaunch() {
        _ = setEnabled(false)
        _ = setEnabled(true)
    }

    private func setEnabled(_ enabled: Bool) -> Bool {
        SMLoginItemSetEnabled("com.maxgoedjen.Secretive.SecretAgent" as CFString, enabled)
    }

}
