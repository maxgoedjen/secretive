import Cocoa
import OSLog
import Combine
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SecretAgentKit
import Brief

import SecretKit
import SecretAgentKitProtocol

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, AgentProtocol {

    private let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    private let updater = Updater(checkOnLaunch: false)
    private let notifier = Notifier()
    private let publicKeyFileStoreController = PublicKeyFileStoreController()
    private lazy var agent: Agent = {
        Agent(storeList: storeList, witness: notifier)
    }()
    private lazy var socketController: SocketController = {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("socket.ssh") as String
        return SocketController(path: path)
    }()
    private var updateSink: AnyCancellable?
    private let logger = Logger()
    var delegate: ServiceDelegate? = nil
    let listener = NSXPCListener(machServiceName: Bundle.main.bundleIdentifier!)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.debug("SecretAgent finished launching")
        DispatchQueue.main.async {
            self.socketController.handler = self.agent.handle(reader:writer:)
        }
        try? publicKeyFileStoreController.generatePublicKeys(for: storeList.stores.flatMap({ $0.secrets }), clear: true)
        notifier.prompt()
        updateSink = updater.$update.sink { update in
            guard let update = update else { return }
            self.notifier.notify(update: update, ignore: self.updater.ignore(release:))
        }
        connect()
    }

    func connect() {
        delegate = ServiceDelegate(exportedObject: self)
        listener.delegate = delegate
        listener.resume()
    }

    func updatedStore(withID id: UUID) async throws {
        logger.debug("Reloading keys for store with id: \(id)")
        guard let store = storeList.modifiableStore, store.id == id else { throw AgentProtocolStoreNotFoundError() }
        try store.reload()
        try publicKeyFileStoreController.generatePublicKeys(for: storeList.stores.flatMap({ $0.secrets }), clear: true)
    }

}

    class ServiceDelegate: NSObject, NSXPCListenerDelegate {

        let exported: AgentProtocol

        init(exportedObject: AgentProtocol) {
            self.exported = exportedObject
        }

        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
            newConnection.exportedInterface = NSXPCInterface(with: AgentProtocol.self)
            newConnection.exportedObject = exported
            newConnection.resume()
            return true
        }

    }
