import Foundation
import Observation
import Security
import CryptoKit
import LocalAuthentication
import SecretKit

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave.
    /// Under the hood, this proxies to two sub-stores – both are backed by the Secure Enclave.
    /// One is a legacy store (VanillaKeychainStore) which stores NIST-P256 keys directly in the keychain.
    /// The other (CryptoKitStore) stores the keys using CryptoKit, and supports additional key types.
    @Observable public final class Store: SecretStoreModifiable {

        @MainActor private let cryptoKit = CryptoKitStore()
        @MainActor private let vanillaKeychain = VanillaKeychainStore()
        @MainActor private var secretSourceMap: [Secret: Source] = [:]

        @MainActor public var secrets: [Secret] = []
        public var isAvailable: Bool {
            CryptoKit.SecureEnclave.isAvailable
        }
        public let id = UUID()
        public let name = String(localized: .secureEnclave)
        public var supportedKeyTypes: [KeyType] {
            cryptoKit.supportedKeyTypes
        }

        private let persistentAuthenticationHandler = PersistentAuthenticationHandler()

        // MARK: SecretStore

        /// Initializes a Store.
        @MainActor public init() {
            reloadSecrets()
            Task {
                for await _ in DistributedNotificationCenter.default().notifications(named: .secretStoreUpdated) {
                     reloadSecretsInternal(notifyAgent: false)
                }
            }
        }

        @MainActor public func reloadSecrets() {
            reloadSecretsInternal(notifyAgent: false)
        }

        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) async throws -> Data {
            try await store(for: secret)
                .sign(data: data, with: secret, for: provenance)
        }

        public func existingPersistedAuthenticationContext(secret: Secret) async -> (any SecretKit.PersistedAuthenticationContext)? {
            await store(for: secret)
                .existingPersistedAuthenticationContext(secret: secret)
        }

        public func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) async throws {
            try await store(for: secret)
                .persistAuthentication(secret: secret, forDuration: duration)
        }

        public func reloadSecrets() async {
            await reloadSecretsInternal()
        }

        // MARK: SecretStoreModifiable

        public func create(name: String, attributes: Attributes) async throws {
            try await cryptoKit.create(name: name, attributes: attributes)
        }

        public func delete(secret: Secret) async throws {
            try await store(for: secret)
                .delete(secret: secret)
        }

        public func update(secret: Secret, name: String, attributes: SecretKit.Attributes) async throws {
            try await store(for: secret)
                .update(secret: secret, name: name, attributes: attributes)
        }

    }

}

extension SecureEnclave.Store {

    fileprivate enum Source {
        case cryptoKit
        case vanilla
    }


    @MainActor func store(for secret: SecretType) -> any SecretStoreModifiable<SecretType> {
        switch secretSourceMap[secret, default: .cryptoKit] {
        case .cryptoKit:
            cryptoKit
        case .vanilla:
            vanillaKeychain
        }
    }

    /// Reloads all secrets from the store.
    /// - Parameter notifyAgent: A boolean indicating whether a distributed notification should be posted, notifying other processes (ie, the SecretAgent) to reload their stores as well.
    @MainActor private func reloadSecretsInternal(notifyAgent: Bool = true) {
        let before = secrets
        var mapped: [SecretType: Source] = [:]
        var new: [SecretType] = []
        cryptoKit.reloadSecrets()
        new.append(contentsOf: cryptoKit.secrets)
        for secret in cryptoKit.secrets {
            mapped[secret] = .cryptoKit
        }
        vanillaKeychain.reloadSecrets()
        new.append(contentsOf: vanillaKeychain.secrets)
        for secret in vanillaKeychain.secrets {
            mapped[secret] = .vanilla
        }
        secretSourceMap = mapped
        secrets = new
        if new != before {
            NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
            if notifyAgent {
                DistributedNotificationCenter.default().postNotificationName(.secretStoreUpdated, object: nil, deliverImmediately: true)
            }
        }
    }


}

extension SecureEnclave {

    enum Constants {
        static let keyTag = Data("com.maxgoedjen.secretive.secureenclave.key".utf8)
    }

}
