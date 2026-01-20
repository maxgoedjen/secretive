import AppKit
import Observation

@MainActor protocol DockVisibilityControllerProtocol: Observable, Sendable {
    var isDockIconVisible: Bool { get }
    func showDockIcon()
    func hideDockIcon()
    func updateVisibility(hasRunSetup: Bool, hasOpenWindows: Bool)
}

@Observable @MainActor final class DockVisibilityController: DockVisibilityControllerProtocol {

    private(set) var isDockIconVisible: Bool = true

    nonisolated init() {}

    func showDockIcon() {
        guard !isDockIconVisible else { return }
        NSApp.setActivationPolicy(.regular)
        isDockIconVisible = true
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideDockIcon() {
        guard isDockIconVisible else { return }
        NSApp.setActivationPolicy(.accessory)
        isDockIconVisible = false
    }

    func updateVisibility(hasRunSetup: Bool, hasOpenWindows: Bool) {
        if !hasRunSetup || hasOpenWindows {
            showDockIcon()
        } else {
            hideDockIcon()
        }
    }
}
