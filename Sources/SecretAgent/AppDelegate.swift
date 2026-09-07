import Cocoa
import OSLog
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SecretAgentKit
import Brief
import Observation
import SSHProtocolKit
import CertificateKit
import Common
import SwiftUI

extension EnvironmentValues {

    @MainActor fileprivate static let _certificateStore: CertificateStore = CertificateStore()

    @MainActor var certificateStore: CertificateStore {
        EnvironmentValues._certificateStore
    }


}
@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @MainActor private let storeList: SecretStoreList = {
        let list = SecretStoreList()
        let cryptoKit = SecureEnclave.Store()
        let migrator = SecureEnclave.CryptoKitMigrator()
        try? migrator.migrate(to: cryptoKit)
        list.add(store: cryptoKit)
        list.add(store: SmartCard.Store())
        let certsMigrator = CertificateMigrator(homeDirectory: URL.homeDirectory, certificateStore: EnvironmentValues._certificateStore)
        try? certsMigrator.migrate()
        return list
    }()
    private let updater = Updater(checkOnLaunch: true)
    private let notifier = Notifier()
    private let publicKeyFileStoreController = PublicKeyFileStoreController(publicKeysURL: URL.publicKeyDirectory, certificatesURL: URL.certificatesDirectory)
    @MainActor private lazy var agent: Agent = {
        Agent(storeList: storeList, certificateStore: EnvironmentValues._certificateStore, witness: notifier)
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
        Task {
            for await _ in NotificationCenter.default.notifications(named: .secretStoreReloaded) {
                try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
            }
        }
        Task {
            for await _ in NotificationCenter.default.notifications(named: .certificateStoreReloaded) {
                try? publicKeyFileStoreController.generateCertificates(for: EnvironmentValues._certificateStore.certificates, clear: true)
            }
        }
        try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
        try? publicKeyFileStoreController.generateCertificates(for: EnvironmentValues._certificateStore.certificates, clear: true)
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

