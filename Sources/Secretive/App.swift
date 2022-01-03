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
    private let agentLaunchController = AgentLaunchController()
    private let agentCommunicationController = AgentCommunicationController()
    private let justUpdatedChecker = JustUpdatedChecker()

    @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
    @State private var showingSetup = false
    @State private var showingCreation = false

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView<Updater, AgentStatusChecker>(showingCreation: $showingCreation, runningSetup: $showingSetup, hasRunSetup: $hasRunSetup)
                .environmentObject(storeList)
                .environmentObject(Updater(checkOnLaunch: hasRunSetup))
                .environmentObject(agentStatusChecker)
                .environmentObject(agentCommunicationController)
                .onAppear {
                    if !hasRunSetup {
                        showingSetup = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    guard hasRunSetup else { return }
                    agentStatusChecker.check()
                    if justUpdatedChecker.justUpdated || !agentStatusChecker.running {
                        // Two conditions in which we reinstall/attempt a force launch:
                        // 1: The app was just updated, and an old version of the agent is alive. Reinstall will deactivate this and activate a new one.
                        // 2: The agent is not running for some reason. We'll attempt to reinstall it, or relaunch directly if that fails.
                        reinstallAgent(uninstallFirst: agentStatusChecker.running) {
                            if agentStatusChecker.noninstanceSecretAgentProcesses.isEmpty {
                                agentLaunchController.killNonInstanceAgents(agents: agentStatusChecker.noninstanceSecretAgentProcesses)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                agentCommunicationController.configure()
                            }
                        }
                    } else {
                        agentCommunicationController.configure()
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
            CommandGroup(after: .help) {
                Button("TEST") {
                    Task {
                        try await agentCommunicationController.agent?.updatedStore(withID: storeList.modifiableStore?.id ?? UUID())
                    }
                }
            }
            SidebarCommands()
        }
    }

}

extension Secretive {

    private func reinstallAgent(uninstallFirst: Bool, completion: @escaping () -> Void) {
        justUpdatedChecker.check()
        agentLaunchController.install(uninstallFirst: uninstallFirst) {
            // Wait a second for launchd to kick in (next runloop isn't enough).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                agentStatusChecker.check()
                if !agentStatusChecker.running {
                    agentLaunchController.forceLaunch { _ in
                        agentStatusChecker.check()
                        completion()
                    }
                } else {
                    completion()
                }
            }
        }
    }

}


private enum Constants {
    static let helpURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md")!
}

