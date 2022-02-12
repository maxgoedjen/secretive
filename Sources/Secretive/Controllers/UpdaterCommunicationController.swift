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

    func configure() {
        guard !running else { return }
        // TODO: Set disabled on launch. Only enable when I have an update to install.
        let x = SMLoginItemSetEnabled("Z72PRUAWF6.com.maxgoedjen.SecretiveUpdater" as CFString, false)
        let y = SMLoginItemSetEnabled("Z72PRUAWF6.com.maxgoedjen.SecretiveUpdater" as CFString, true)
        connection = NSXPCConnection(machServiceName: "Z72PRUAWF6.com.maxgoedjen.SecretiveUpdater")
        connection?.remoteObjectInterface = NSXPCInterface(with: UpdaterProtocol.self)
        connection?.invalidationHandler = {
            Logger().warning("XPC connection invalidated")
        }
        connection?.resume()
        updater = connection?.remoteObjectProxyWithErrorHandler({ error in
            Logger().error("\(String(describing: error))")
        }) as? UpdaterProtocol
        Task {
            print(try await updater?.installUpdate(url: URL(string: "https://google.com")!))
        }
        running = true
    }

}


