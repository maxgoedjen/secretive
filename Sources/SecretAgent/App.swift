import Cocoa
import OSLog
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SecretAgentKit
import Brief
import Observation
import Common
import SwiftUI
import CertificateKit

@main
struct SecretAgent: App {

    @MainActor private let storeList: SecretStoreList = {
        let list = SecretStoreList()
        let cryptoKit = SecureEnclave.Store()
        let migrator = SecureEnclave.CryptoKitMigrator()
        try? migrator.migrate(to: cryptoKit)
        list.add(store: cryptoKit)
        list.add(store: SmartCard.Store())
        return list
    }()
    @MainActor private let certificateStore: CertificateStore = CertificateStore()

    private let updater = Updater(checkOnLaunch: true)
    private let notifier = Notifier()
    private let authenticationHandler = AuthenticationHandler()
    private let publicKeyFileStoreController = PublicKeyFileStoreController(publicKeysURL: URL.publicKeyDirectory, certificatesURL: URL.certificatesDirectory)

    @State var pending: ([[SignatureRequest]], (Set<SignatureRequest>) async throws -> Void)?
    @Environment(\.openWindow) var openWindow

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "App")
    @SceneBuilder var body: some Scene {
        MenuBarExtra(isInserted: .constant(false)) {
            EmptyView()
        } label: {
            Image(systemName: "lock")
                .task {
                    await notifier.registerPersistenceHandler {
                        try await authenticationHandler.persistAuthentication(secret: $0, forDuration: $1)
                    }
                }
                .task {
                    let socketController = SocketController(path: URL.socketPath)
                    let agent = Agent(
                        storeList: storeList,
                        certificateStore: certificateStore,
                        authenticationHandler: authenticationHandler,
                        witness: notifier
                    )
                    for await session in socketController.sessions {
                        Task {
                            do {
                                let inputParser = try await XPCAgentInputParser()
                                for await message in session.messages {
                                    let request = try await inputParser.parse(data: message)
                                    let agentResponse = await agent.handle(request: request, provenance: session.provenance)
                                    try session.write(agentResponse)
                                }
                            } catch {
                                try? session.close()
                            }
                        }
                    }
                }
//                .task {
//                    let socketController = SocketController(path:     URL.agentHomeURL.appendingPathComponent("socket-two.ssh").path())
//                    let socketController = SocketController(path: "/Users/max/Downloads/test.ssh")
//                    let agent = Agent(storeList: storeList, authenticationHandler: authenticationHandler, witness: notifier)
//                    for await session in socketController.sessions {
//                        Task {
//                            let inputParser = try await XPCAgentInputParser()
//                            do {
//                                for await message in session.messages {
//                                    let request = try await inputParser.parse(data: message)
//                                    let agentResponse = await agent.handle(request: request, provenance: session.provenance)
//                                    try session.write(agentResponse)
//                                }
//                            } catch {
//                                try session.close()
//                            }
//                        }
//                    }
//                }
                .task {
                    try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
                    for await _ in NotificationCenter.default.notifications(named: .secretStoreReloaded) {
                        try? publicKeyFileStoreController.generatePublicKeys(for: storeList.allSecrets, clear: true)
                    }
                }
                .task {
                    let certsMigrator = CertificateMigrator(homeDirectory: URL.homeDirectory, certificateStore: certificateStore)
                    try? certsMigrator.migrate()
                    try? publicKeyFileStoreController.generateCertificates(for: certificateStore.certificates, clear: true)
                    for await _ in NotificationCenter.default.notifications(named: .certificateStoreReloaded) {
                        try? publicKeyFileStoreController.generateCertificates(for: certificateStore.certificates, clear: true)
                    }
                }
                .task {
                    await authenticationHandler.setBatchAuthHandler { @MainActor pending, authorize in
                        self.pending = (pending, authorize)
                        openWindow(id: String(describing: BatchedRequestsView.self))
                    }

                }
                .task {
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
        WindowGroup(id: String(describing: BatchedRequestsView.self)) {
            pendingView
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

    @ViewBuilder
    var pendingView: some View {
        if let (requests, authorize) = pending {
            BatchedRequestsView(pending: requests, review: authorize)
        }
    }


}
