import Cocoa
import SwiftUI
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief

@main
struct Secretive: App {

    private let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    private let agentStatusChecker = AgentStatusChecker()
    private let justUpdatedChecker = JustUpdatedChecker()

    @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
    @State private var showingSetup = false
    @State private var showingCreation = false

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView<Updater, AgentStatusChecker>(showingCreation: $showingCreation, runningSetup: $showingSetup, hasRunSetup: $hasRunSetup)
                .environmentObject(storeList)
                .environmentObject(Updater(checkOnLaunch: hasRunSetup, bundlePrefix: BundlePrefix))
                .environmentObject(agentStatusChecker)
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
                Button("New Secret") {
                    showingCreation = true
                }
                .keyboardShortcut(KeyboardShortcut(KeyEquivalent("N"), modifiers: [.command, .shift]))
            }
            CommandGroup(replacing: .help) {
                Button("Help") {
                    NSWorkspace.shared.open(Constants.helpURL)
                }
            }
            CommandGroup(after: .help) {
                Button("Setup Secretive") {
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
        LaunchAgentController().install {
            // Wait a second for launchd to kick in (next runloop isn't enough).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                agentStatusChecker.check()
                if !agentStatusChecker.running {
                    forceLaunchAgent()
                }
            }
        }
    }

    private func forceLaunchAgent() {
        // We've run setup, we didn't just update, launchd is just not doing it's thing.
        // Force a launch directly.
        LaunchAgentController().forceLaunch { _ in
            agentStatusChecker.check()
        }
    }

}


private enum Constants {
    static let helpURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md")!
}

