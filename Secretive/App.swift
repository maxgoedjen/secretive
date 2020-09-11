import Cocoa
import SwiftUI
import SecretKit
import Brief

@main
struct AppDelegate: App {

    let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    let updater = Updater()
    let agentStatusChecker = AgentStatusChecker()
    let justUpdatedChecker = JustUpdatedChecker()

    @State var showingSetup = false
    @AppStorage("defaultsHasRunSetup") var hasRunSetup = false

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView<Updater, AgentStatusChecker>(runningSetup: $showingSetup)
                .environmentObject(storeList)
                .environmentObject(updater)
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
                        _ = LaunchAgentController().install()
                    }

                }
        }
        .commands {
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button("New Secret") {
                    // TODO: Add
                }
                .keyboardShortcut(KeyboardShortcut(KeyEquivalent("N"), modifiers: .command))
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

