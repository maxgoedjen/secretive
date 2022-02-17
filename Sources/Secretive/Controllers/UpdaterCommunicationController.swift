import Foundation
import Combine
import AppKit
import OSLog
import SecretKit
//import SecretiveUpdater
import ServiceManagement

class UpdaterCommunicationController: ObservableObject {

    private(set) var updater: UpdaterProtocol? = nil
    private var connection: NSXPCConnection? = nil
    private var running = false

    init() {
    }

    func installUpdate(url: URL) {
        guard !running else { return }
       _ = SMLoginItemSetEnabled(Bundle.main.updaterBundleID as CFString, false)
        SMLoginItemSetEnabled(Bundle.main.updaterBundleID as CFString, true)
        connection = NSXPCConnection(machServiceName: Bundle.main.updaterBundleID)
        connection?.remoteObjectInterface = NSXPCInterface(with: UpdaterProtocol.self)
        connection?.invalidationHandler = {
            Logger().warning("XPC connection invalidated")
        }
        connection?.resume()
        updater = connection?.remoteObjectProxyWithErrorHandler({ error in
            Logger().error("\(String(describing: error))")
        }) as? UpdaterProtocol
        running = true
        let existingURL = Bundle.main.bundleURL
        Task {
            let result = try await updater?.installUpdate(url: url, to: existingURL)
            print(result)
        }
    }

}


