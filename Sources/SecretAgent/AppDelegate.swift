import Cocoa
import OSLog
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
        let cryptoKit = SecureEnclave.Store()
        let migrator = SecureEnclave.CryptoKitMigrator()
        try? migrator.migrate(to: cryptoKit)
        list.add(store: cryptoKit)
        list.add(store: SmartCard.Store())
        return list
    }()
    private let updater = Updater(checkOnLaunch: true)
    private let notifier = Notifier()
    private let publicKeyFileStoreController = PublicKeyFileStoreController(homeDirectory: URL.homeDirectory)
    private lazy var agent: Agent = {
        Agent(storeList: storeList, witness: notifier)
    }()
    private lazy var socketController: SocketController = {
        let path = (NSHomeDirectory() as NSString).appendingPathComponent("socket.ssh") as String
        return SocketController(path: path)
    }()
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "AppDelegate")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.debug("SecretAgent finished launching")
        Task {
            for await session in socketController.sessions {
                Task {
                    do {
                        for await message in session.messages {
                            let agentResponse = try await agent.handle(data: message, provenance: session.provenance)
                            try await session.write(agentResponse)
                        }
                    } catch {
                        try session.close()
                    }
                }
            }
        }
        Task {
            for await _ in NotificationCenter.default.notifications(named: .secretStoreReloaded) {
                try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
            }
        }
        try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
        notifier.prompt()
        _ = withObservationTracking {
            updater.update
        } onChange: { [updater, notifier] in
            Task {
                guard !updater.currentVersion.isTestBuild else { return }
                await notifier.notify(update: updater.update!) { release in
                    await updater.ignore(release: release)
                }
            }
        }
    }

}

