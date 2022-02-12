import Foundation
import Combine
import AppKit
import OSLog
import SecretKit
import SecretiveUpdater

class UpdaterCommunicationController: ObservableObject {

    private(set) var updater: UpdaterProtocol? = nil
    private var connection: NSXPCConnection? = nil
    private var running = false

    init() {
    }

    func configure() {
        guard !running else { return }
        connection = NSXPCConnection(serviceName: "com.maxgoedjen.SecretiveUpdater")
        connection?.remoteObjectInterface = NSXPCInterface(with: UpdaterProtocol.self)
        connection?.invalidationHandler = {
            Logger().warning("XPC connection invalidated")
        }
        connection?.resume()
        updater = connection?.remoteObjectProxyWithErrorHandler({ error in
            Logger().error("\(String(describing: error))")
        }) as? UpdaterProtocol
        running = true
    }

}


