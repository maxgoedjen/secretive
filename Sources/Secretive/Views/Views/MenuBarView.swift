import SwiftUI

struct MenuBarView: View {

    @Environment(\.openWindow) private var openWindow
    @Environment(\.agentLaunchController) private var agentLaunchController

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            agentStatusSection
            Divider()
            actionsSection
            Divider()
            appSection
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var agentStatusSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(agentLaunchController.running ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(agentLaunchController.running ? "Agent Running" : "Agent Not Running")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionsSection: some View {
        Button("Open Secretive") {
            openMainWindow()
        }
        .keyboardShortcut("O", modifiers: [.command])

        Button("Integrations...") {
            openWindow(id: String(describing: IntegrationsView.self))
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @ViewBuilder
    private var appSection: some View {
        Button("About Secretive") {
            openWindow(id: String(describing: AboutView.self))
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit Secretive") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("Q", modifiers: [.command])
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
