import Cocoa
import SwiftUI
import SecretKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    @IBOutlet var toolbar: NSToolbar!
    let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    let updater = Updater()
    let agentStatusChecker = AgentStatusChecker()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = ContentView(storeList: storeList, updater: updater, agentStatusChecker: agentStatusChecker, runSetupBlock: { self.runSetup(sender: nil) })
        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.titleVisibility = .hidden
        window.toolbar = toolbar
        window.isReleasedWhenClosed = false
        if storeList.modifiableStore?.isAvailable ?? false {
            let plus = NSTitlebarAccessoryViewController()
            plus.view = NSButton(image: NSImage(named: NSImage.addTemplateName)!, target: self, action: #selector(add(sender:)))
            plus.layoutAttribute = .right
            window.addTitlebarAccessoryViewController(plus)
        }
        runSetupIfNeeded()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        agentStatusChecker.check()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return false }
        window.makeKeyAndOrderFront(self)
        return true
    }

    @IBAction func add(sender: AnyObject?) {
        var addWindow: NSWindow!
        let addView = CreateSecretView(store: storeList.modifiableStore!) {
            self.window.endSheet(addWindow)
        }
        addWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        addWindow.contentView = NSHostingView(rootView: addView)
        window.beginSheet(addWindow, completionHandler: nil)
    }

    @IBAction func runSetup(sender: AnyObject?) {
        let setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        let setupView = SetupView() { success in
            self.window.endSheet(setupWindow)
            self.agentStatusChecker.check()
        }
        setupWindow.contentView = NSHostingView(rootView: setupView)
        window.beginSheet(setupWindow, completionHandler: nil)
    }

}

extension AppDelegate {

    func runSetupIfNeeded() {
        if !UserDefaults.standard.bool(forKey: Constants.defaultsHasRunSetup) {
            UserDefaults.standard.set(true, forKey: Constants.defaultsHasRunSetup)
            runSetup(sender: nil)
        }
    }

}

extension AppDelegate {

    enum Constants {
        static let defaultsHasRunSetup = "defaultsHasRunSetup"
    }

}
