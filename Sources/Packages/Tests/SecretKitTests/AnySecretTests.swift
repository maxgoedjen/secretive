import Foundation
import Testing
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit


@Suite struct AnySecretTests {

    @Test func eraser() {
        let data = Data(UUID().uuidString.utf8)
        let secret = SmartCard.Secret(id: data, name: "Name", publicKey: data, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 256), authentication: .notRequired))
        let erased = AnySecret(secret)
        #expect(erased.id == secret.id as AnyHashable)
        #expect(erased.name == secret.name)
        #expect(erased.keyType == secret.keyType)
        #expect(erased.publicKey == secret.publicKey)
    }

    @Test @MainActor func eraserForwardsReloadRequirement() {
        let store = ReloadTrackingStore()
        let erased = AnySecretStore(store)

        #expect(erased.secretsNeedReload)
        store.secretsNeedReload = false
        #expect(!erased.secretsNeedReload)
    }

}

private struct ReloadTrackingSecret: Secret {
    let id = UUID()
    let name = "Test"
    let publicKey = Data()
    let attributes = Attributes(keyType: .ecdsa256, authentication: .notRequired)
}

@MainActor private final class ReloadTrackingStore: SecretStore, @unchecked Sendable {
    let id = UUID()
    let isAvailable = true
    let name = "Test"
    var secrets: [ReloadTrackingSecret] = []
    var secretsNeedReload = true

    func sign(data: Data, with secret: ReloadTrackingSecret, for provenance: SigningRequestProvenance) async throws -> Data {
        Data()
    }

    func existingPersistedAuthenticationContext(secret: ReloadTrackingSecret) async -> PersistedAuthenticationContext? {
        nil
    }

    func persistAuthentication(secret: ReloadTrackingSecret, forDuration duration: TimeInterval) async throws {
    }

    func reloadSecrets() {
    }
}
