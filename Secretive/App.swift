import Cocoa
import SwiftUI
import SecretKit
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

    @State private var showingSetup = false
    @State private var showingCreation = false
    @AppStorage("defaultsHasRunSetup") var hasRunSetup = false

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView<Updater, AgentStatusChecker>(showingCreation: $showingCreation, runningSetup: $showingSetup)
                .environmentObject(storeList)
                .environmentObject(Updater(checkOnLaunch: hasRunSetup))
                .environmentObject(agentStatusChecker)
                .sheet(isPresented: $showingSetup) {
                    SetupView { completed in
                        showingSetup = false
                        hasRunSetup = completed
                    }
                }
                .onAppear {
                    if !hasRunSetup {
                        showingSetup = true
                    }
                    if agentStatusChecker.running && justUpdatedChecker.justUpdated {
                        // Relaunch the agent, since it'll be running from earlier update still
                        _ = LaunchAgentController().install()
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
                Button("Setup Secret Agent") {
                    showingSetup = true
                }
            }
        }
    }

}


private enum Constants {
    static let helpURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md")!
}

