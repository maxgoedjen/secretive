import SwiftUI
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief

extension EnvironmentValues {

    // This is injected through .environment modifier below instead of @Entry for performance reasons (basially, restrictions around init/mainactor causing delay in loading secrets/"empty screen" blip).
    @MainActor fileprivate static let _secretStoreList: SecretStoreList = {
        let list = SecretStoreList()
        let cryptoKit = SecureEnclave.Store()
        let migrator = SecureEnclave.CryptoKitMigrator()
        try? migrator.migrate(to: cryptoKit)
        list.add(store: cryptoKit)
        list.add(store: SmartCard.Store())
        return list
    }()

    private static let _agentStatusChecker = AgentStatusChecker()
    @Entry var agentStatusChecker: any AgentStatusCheckerProtocol = _agentStatusChecker
    private static let _updater: any UpdaterProtocol = {
        @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
        return Updater(checkOnLaunch: hasRunSetup)
    }()
    @Entry var updater: any UpdaterProtocol = _updater

    @MainActor var secretStoreList: SecretStoreList {
        EnvironmentValues._secretStoreList
    }
}

@main
struct Secretive: App {
    
    private let justUpdatedChecker = JustUpdatedChecker()
    @Environment(\.agentStatusChecker) var agentStatusChecker
    @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
    @State private var showingSetup = false
    @State private var showingCreation = false

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView(showingCreation: $showingCreation, runningSetup: $showingSetup, hasRunSetup: $hasRunSetup)
                .environment(EnvironmentValues._secretStoreList)
                .onAppear {
                    if !hasRunSetup {
                        showingSetup = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    guard hasRunSetup else { return }
                    agentStatusChecker.check()
                    if agentStatusChecker.running && justUpdatedChecker.justUpdated {
                        // Relaunch the agent, since it'll be running from earlier update still
                        reinstallAgent()
                    } else if !agentStatusChecker.running && !agentStatusChecker.developmentBuild {
                        forceLaunchAgent()
                    }
                }
        }
        .commands {
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button(.appMenuNewSecretButton) {
                    showingCreation = true
                }
                .keyboardShortcut(KeyboardShortcut(KeyEquivalent("N"), modifiers: [.command, .shift]))
            }
            CommandGroup(replacing: .help) {
                Button(.appMenuHelpButton) {
                    NSWorkspace.shared.open(Constants.helpURL)
                }
            }
            CommandGroup(before: .help) {
                Button(.appMenuSetupButton) {
                    showingSetup = true
                }
            }
            SidebarCommands()
        }
    }

}

extension Secretive {

    private func reinstallAgent() {
        justUpdatedChecker.check()
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

