import Cocoa
import OSLog
import Combine
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SecretAgentKit
import Brief
import Observation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @MainActor private let storeList: SecretStoreList = {
        let list = SecretStoreList()
        list.add(store: SecureEnclave.Store())
        list.add(store: SmartCard.Store())
        return list
    }()
    private let updater = Updater(checkOnLaunch: true)
    private let notifier = Notifier()
    private let publicKeyFileStoreController = PublicKeyFileStoreController(homeDirectory: NSHomeDirectory())
    private lazy var agent: Agent = {
        Agent(storeList: storeList, witness: notifier)
    }()
    private lazy var socketController: SocketController = {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("socket.ssh") as String
        return SocketController(path: path)
    }()
    private var updateSink: AnyCancellable?
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "AppDelegate")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.debug("SecretAgent finished launching")
        Task { @MainActor in
            socketController.handler = { [agent] reader, writer in
                await agent.handle(reader: reader, writer: writer)
            }
        }
        Task {
            for await _ in NotificationCenter.default.notifications(named: .secretStoreReloaded) {
                try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
            }
        }
        try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
        notifier.prompt()
//        _ = withObservationTracking {
//            updater.update
//        } onChange: { [updater, notifier] in
//            notifier.notify(update: updater.update!) { release in
//                Task {
//                    await updater.ignore(release: release)
//                }
//            }
//        }
    }

}

