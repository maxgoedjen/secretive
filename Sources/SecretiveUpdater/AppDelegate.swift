import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let delegate = ServiceDelegate(exportedObject: Updater())
    let listener = NSXPCListener(machServiceName: Bundle.main.bundleIdentifier!)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        listener.delegate = delegate
        listener.resume()
        Task {
            try! await delegate.exported.authorize()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }


}

class ServiceDelegate: NSObject, NSXPCListenerDelegate {

    let exported: UpdaterProtocol

    init(exportedObject: UpdaterProtocol) {
        self.exported = exportedObject
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: UpdaterProtocol.self)
        newConnection.exportedObject = exported
        newConnection.resume()
        return true
    }

}

