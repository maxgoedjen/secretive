import SwiftUI
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief
import CertificateKit

@main
struct Secretive: App {
    
    @Environment(\.agentStatusChecker) var agentStatusChecker
    @Environment(\.justUpdatedChecker) var justUpdatedChecker

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(EnvironmentValues._secretStoreList)
                .environment(EnvironmentValues._certificateStore)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
                    guard hasRunSetup else { return }
                    agentStatusChecker.check()
                    if agentStatusChecker.running && justUpdatedChecker.justUpdatedBuild {
                        // Relaunch the agent, since it'll be running from earlier update still
                        reinstallAgent()
                    } else if !agentStatusChecker.running && !agentStatusChecker.developmentBuild {
                        forceLaunchAgent()
                    }
                }
        }
        .commands {
            AppCommands()
        }
        WindowGroup(id: String(describing: IntegrationsView.self)) {
            IntegrationsView()
        }
        .windowResizability(.contentMinSize)
        WindowGroup(id: String(describing: AboutView.self)) {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

}

extension Secretive {

    struct AppCommands: Commands {

        @Environment(\.openWindow) var openWindow
        @Environment(\.openURL) var openURL
        @FocusedValue(\.showCreateSecret) var showCreateSecret

        var body: some Commands {
            CommandGroup(replacing: .appInfo) {
                Button(.aboutMenuBarTitle, systemImage: "info.circle") {
                    openWindow(id: String(describing: AboutView.self))
                }
            }
            CommandGroup(before: CommandGroupPlacement.appSettings) {
                Button(.integrationsMenuBarTitle, systemImage: "app.connected.to.app.below.fill") {
                    openWindow(id: String(describing: IntegrationsView.self))
                }
            }
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button(.appMenuNewSecretButton, systemImage: "plus") {
                    showCreateSecret?()
                }
                .keyboardShortcut(KeyboardShortcut(KeyEquivalent("N"), modifiers: [.command, .shift]))
                .disabled(showCreateSecret?.isEnabled == false)
            }
            CommandGroup(replacing: .help) {
                Button(.appMenuHelpButton) {
                    openURL(Constants.helpURL)
                }
            }
            SidebarCommands()
        }
    }

}

extension Secretive {

    private func reinstallAgent() {
        Task {
            _ = await LaunchAgentController().install()
            try? await Task.sleep(for: .seconds(1))
            agentStatusChecker.check()
            if !agentStatusChecker.running {
                forceLaunchAgent()
            }
        }
    }

    private func forceLaunchAgent() {
        // We've run setup, we didn't just update, launchd is just not doing it's thing.
        // Force a launch directly.
        Task {
            _ = await LaunchAgentController().forceLaunch()
            agentStatusChecker.check()
        }
    }

}

private enum Constants {
    static let helpURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md")!
}


extension EnvironmentValues {

    // This is injected through .environment modifier below instead of @Entry for performance reasons (basially, restrictions around init/mainactor causing delay in loading secrets/"empty screen" blip).
    @MainActor fileprivate static let _secretStoreList: SecretStoreList = {
        let list = SecretStoreList()
        let cryptoKit = SecureEnclave.Store()
        let cryptoKitMigrator = SecureEnclave.CryptoKitMigrator()
        try? cryptoKitMigrator.migrate(to: cryptoKit)
        list.add(store: cryptoKit)
        list.add(store: SmartCard.Store())
        return list
    }()

    @MainActor fileprivate static let _certificateStore: CertificateStore = CertificateStore()

    private static let _agentStatusChecker = AgentStatusChecker()
    @Entry var agentStatusChecker: any AgentStatusCheckerProtocol = _agentStatusChecker
    private static let _updater: any UpdaterProtocol = {
        @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
        return Updater(checkOnLaunch: hasRunSetup)
    }()
    @Entry var updater: any UpdaterProtocol = _updater

    private static let _justUpdatedChecker = JustUpdatedChecker()
    @Entry var justUpdatedChecker: any JustUpdatedCheckerProtocol = _justUpdatedChecker

    @MainActor var secretStoreList: SecretStoreList {
        EnvironmentValues._secretStoreList
    }

    @MainActor var certificateStore: CertificateStore {
        EnvironmentValues._certificateStore
    }
}

extension FocusedValues {
    @Entry var showCreateSecret: OpenSheet?
}

final class OpenSheet {

    let closure: () -> Void
    let isEnabled: Bool

    init(isEnabled: Bool = true, closure: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.closure = closure
    }

    func callAsFunction() {
        closure()
    }

}
