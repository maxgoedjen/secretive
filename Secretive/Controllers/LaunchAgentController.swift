import Foundation
import ServiceManagement

struct LaunchAgentController {

    func install() -> Bool {
        _ = setEnabled(false)
        return setEnabled(true)
    }

    private func setEnabled(_ enabled: Bool) -> Bool {
        SMLoginItemSetEnabled("com.maxgoedjen.Secretive.SecretAgent" as CFString, enabled)
    }

}
