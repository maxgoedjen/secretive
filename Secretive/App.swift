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

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView<Updater, AgentStatusChecker>(runSetupBlock: { self.runSetup(sender: nil) })
                .environmentObject(storeList)
                .environmentObject(updater)
                .environmentObject(agentStatusChecker)
        }
        WindowGroup {
            SetupView() { _ in
                print("Setup")
            }
        }
    }

}

extension AppDelegate {

    func runSetup(sender: AnyObject?) {
        let setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        let setupView = SetupView() { success in
//            self.window.endSheet(setupWindow)
            self.agentStatusChecker.check()
        }
        setupWindow.contentView = NSHostingView(rootView: setupView)
//        window.beginSheet(setupWindow, completionHandler: nil)
    }

    func runSetupIfNeeded() {
        if !UserDefaults.standard.bool(forKey: Constants.defaultsHasRunSetup) {
            UserDefaults.standard.set(true, forKey: Constants.defaultsHasRunSetup)
            runSetup(sender: nil)
        }
    }

    func relaunchAgentIfNeeded() {
        if agentStatusChecker.running && justUpdatedChecker.justUpdated {
            LaunchAgentController().relaunch()
        }
    }

}

extension AppDelegate {

    enum Constants {
        static let defaultsHasRunSetup = "defaultsHasRunSetup"
    }

}
