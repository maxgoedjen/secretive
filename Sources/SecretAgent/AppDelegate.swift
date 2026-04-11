import Cocoa
import OSLog
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SecretAgentKit
import Brief
import Observation
import Common

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
    private let authenticationHandler = AuthenticationHandler { pending, authorize in
        print(pending)
        print("Waiting")
//        Task {
            try await Task.sleep(for: .seconds(3))
            try await authorize(pending)
//        }
    }
    private let publicKeyFileStoreController = PublicKeyFileStoreController(directory: URL.publicKeyDirectory)
    private lazy var agent: Agent = {
        Agent(storeList: storeList, authenticationHandler: authenticationHandler, witness: notifier)
    }()
    private lazy var socketController: SocketController = {
        let path = URL.socketPath as String
        return SocketController(path: path)
    }()
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "AppDelegate")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.debug("SecretAgent finished launching")
        Task {
            for await session in socketController.sessions {
                Task {
                    let inputParser = try await XPCAgentInputParser()
                    do {
                        for await message in session.messages {
                            let request = try await inputParser.parse(data: message)
                            let agentResponse = await agent.handle(request: request, provenance: session.provenance)
                            try session.write(agentResponse)
                        }
                    } catch {
                        try session.close()
                    }
                }
            }
        }
        Task { [notifier, authenticationHandler] in
            await notifier.registerPersistenceHandler {
                try await authenticationHandler.persistAuthentication(secret: $0, forDuration: $1)
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

