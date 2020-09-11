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
            ContentView<Updater, AgentStatusChecker>()
                .environmentObject(storeList)
                .environmentObject(updater)
                .environmentObject(agentStatusChecker)
                .sheet(isPresented: $showingSetup) {
                    SetupView { completed in
                        self.showingSetup = false
                        self.hasRunSetup = completed
                    }
                }
                .onAppear {
                    if !hasRunSetup {
                        showingSetup = true
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
                    self.showingSetup = true
                }
            }
        }
    }

}


private enum Constants {
    static let helpURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md")!
}

