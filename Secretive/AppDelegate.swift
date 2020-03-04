import Cocoa
import SwiftUI
import SecretKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!
    @IBOutlet var toolbar: NSToolbar!
    let secureEnclave = SecureEnclave.Store()
    let yubikey = SmartCard.Store()

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let contentView = ContentView(store: secureEnclave)
//        try! secureEnclave.create(name: "SecretiveTest")
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
        let plus = NSTitlebarAccessoryViewController()
        plus.view = NSButton(image: NSImage(named: NSImage.addTemplateName)!, target: self, action: #selector(add(sender:)))
        plus.layoutAttribute = .right
        window.addTitlebarAccessoryViewController(plus)
        runSetupIfNeeded()
    }

    @IBAction func add(sender: AnyObject?) {
        var addWindow: NSWindow!
        let addView = CreateSecureEnclaveSecretView(store: secureEnclave) {
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
