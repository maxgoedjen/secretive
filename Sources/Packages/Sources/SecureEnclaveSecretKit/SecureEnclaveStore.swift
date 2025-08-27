import Foundation
import Observation
import Security
import CryptoKit
@preconcurrency import LocalAuthentication
import SecretKit
import os

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave using CryptoKit API.
    @Observable public final class Store: SecretStoreModifiable {

        @MainActor public var secrets: [Secret] = []
        public var isAvailable: Bool {
            CryptoKit.SecureEnclave.isAvailable
        }
        public let id = UUID()
        public let name = String(localized: .secureEnclave)
        private let persistentAuthenticationHandler = PersistentAuthenticationHandler()

        /// Initializes a Store.
        @MainActor public init() {
            loadSecrets()
            Task {
                for await _ in DistributedNotificationCenter.default().notifications(named: .secretStoreUpdated) {
                    reloadSecrets()
                }
            }
        }

        // MARK: - Public API
        
        // MARK: SecretStore
        
        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) async throws -> Data {
            var context: LAContext
            if let existing = await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret) {
                context = existing.context
            } else {
                let newContext = LAContext()
                newContext.localizedReason = String(localized: .authContextRequestSignatureDescription(appName: provenance.origin.displayName, secretName: secret.name))
                newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)
                context = newContext
            }

            let queryAttributes = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrService: Constants.keyTag,
                kSecUseDataProtectionKeychain: true,
                kSecAttrAccount: secret.id,
                kSecReturnAttributes: true,
                kSecReturnData: true,
            ])
            var untyped: CFTypeRef?
            let status = SecItemCopyMatching(queryAttributes, &untyped)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            guard let untypedSafe = untyped as? [CFString: Any] else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            guard let attributesData = untypedSafe[kSecAttrGeneric] as? Data,
                  let keyData = untypedSafe[kSecValueData] as? Data else {
                throw MissingAttributesError()
            }
            let attributes = try JSONDecoder().decode(Attributes.self, from: attributesData)

            switch (attributes.keyType.algorithm, attributes.keyType.size) {
            case (.ecdsa, 256):
                let key = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData, authenticationContext: context)
                return try key.signature(for: data).rawRepresentation
            case (.mldsa, 65):
                guard #available(macOS 26.0, *)  else { throw UnsupportedAlgorithmError() }
                let key = try CryptoKit.SecureEnclave.MLDSA65.PrivateKey(dataRepresentation: keyData)
                return try key.signature(for: data)
            case (.mldsa, 87):
                guard #available(macOS 26.0, *)  else { throw UnsupportedAlgorithmError() }
                let key = try CryptoKit.SecureEnclave.MLDSA87.PrivateKey(dataRepresentation: keyData)
                return try key.signature(for: data)
            default:
                throw UnsupportedAlgorithmError()
            }

        }

        public func existingPersistedAuthenticationContext(secret: Secret) async -> PersistedAuthenticationContext? {
            await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret)
        }

        public func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) async throws {
            try await persistentAuthenticationHandler.persistAuthentication(secret: secret, forDuration: duration)
        }

        @MainActor public func reloadSecrets() {
            reloadSecretsInternal(notifyAgent: false)
        }

        // MARK: SecretStoreModifiable
        
        public func create(name: String, attributes: Attributes) async throws -> Secret {
            var accessError: SecurityError?
            let flags: SecAccessControlCreateFlags = switch attributes.authentication {
            case .notRequired:
                []
            case .presenceRequired:
                [.userPresence, .privateKeyUsage]
            case .biometryCurrent:
                [.biometryCurrentSet, .privateKeyUsage]
            case .unknown:
                fatalError()
            }
            let access =
                SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                flags,
                                                &accessError)
            if let error = accessError {
                throw error.takeRetainedValue() as Error
            }
            let dataRep: Data
            let publicKey: Data
            switch (attributes.keyType.algorithm, attributes.keyType.size) {
            case (.ecdsa, 256):
                let created = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(accessControl: access!)
                dataRep = created.dataRepresentation
                publicKey = created.publicKey.x963Representation
            case (.mldsa, 65):
                guard #available(macOS 26.0, *) else { throw Attributes.UnsupportedOptionError() }
                let created = try CryptoKit.SecureEnclave.MLDSA65.PrivateKey(accessControl: access!)
                dataRep = created.dataRepresentation
                publicKey = created.publicKey.rawRepresentation
            case (.mldsa, 87):
                guard #available(macOS 26.0, *) else { throw Attributes.UnsupportedOptionError() }
                let created = try CryptoKit.SecureEnclave.MLDSA87.PrivateKey(accessControl: access!)
                dataRep = created.dataRepresentation
                publicKey = created.publicKey.rawRepresentation
            default:
                throw Attributes.UnsupportedOptionError()
            }
            let id = try saveKey(dataRep, name: name, attributes: attributes)
            await reloadSecrets()
            return Secret(id: id, name: name, publicKey: publicKey, attributes: attributes)
        }

        public func delete(secret: Secret) async throws {
            let deleteAttributes = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrService: Constants.keyTag,
                kSecUseDataProtectionKeychain: true,
                kSecAttrAccount: secret.id,
            ])
            let status = SecItemDelete(deleteAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            await reloadSecrets()
        }

        public func update(secret: Secret, name: String, attributes: Attributes) async throws {
            let updateQuery = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrAccount: secret.id,
            ])

            let attributes = try JSONEncoder().encode(attributes)
            let updatedAttributes = KeychainDictionary([
                kSecAttrLabel: name,
                kSecAttrGeneric: attributes,
            ])

            let status = SecItemUpdate(updateQuery, updatedAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            await reloadSecrets()
        }
        
        public var supportedKeyTypes: [KeyType] {
            [
                .init(algorithm: .ecdsa, size: 256),
                .init(algorithm: .mldsa, size: 65),
                .init(algorithm: .mldsa, size: 87),
            ]
        }

    }

}

extension SecureEnclave.Store {

    @MainActor private func reloadSecretsInternal(notifyAgent: Bool = true) {
        let before = secrets
        secrets.removeAll()
        loadSecrets()
        if secrets != before {
            NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
            if notifyAgent {
                DistributedNotificationCenter.default().postNotificationName(.secretStoreUpdated, object: nil, deliverImmediately: true)
            }
        }
    }

    /// Loads all secrets from the store.
    @MainActor private func loadSecrets() {
        let queryAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: Constants.keyTag,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ])
        var untyped: CFTypeRef?
        SecItemCopyMatching(queryAttributes, &untyped)
        guard let typed = untyped as? [[CFString: Any]] else { return }
        let wrapped: [SecureEnclave.Secret] = typed.compactMap {
            do {
                let name = $0[kSecAttrLabel] as? String ?? String(localized: "unnamed_secret")
                guard let attributesData = $0[kSecAttrGeneric] as? Data,
                let id = $0[kSecAttrAccount] as? String else {
                    throw MissingAttributesError()
                }
                let attributes = try JSONDecoder().decode(Attributes.self, from: attributesData)
                let keyData = $0[kSecValueData] as! Data
                let publicKey: Data
                switch (attributes.keyType.algorithm, attributes.keyType.size) {
                case (.ecdsa, 256):
                    let key = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
                    publicKey = key.publicKey.x963Representation
                case (.mldsa, 65):
                    guard #available(macOS 26.0, *)  else { throw UnsupportedAlgorithmError() }
                    let key = try CryptoKit.SecureEnclave.MLDSA65.PrivateKey(dataRepresentation: keyData)
                    publicKey = key.publicKey.rawRepresentation
                case (.mldsa, 87):
                    guard #available(macOS 26.0, *)  else { throw UnsupportedAlgorithmError() }
                    let key = try CryptoKit.SecureEnclave.MLDSA87.PrivateKey(dataRepresentation: keyData)
                    publicKey = key.publicKey.rawRepresentation
                default:
                    throw UnsupportedAlgorithmError()
                }
                return SecureEnclave.Secret(id: id, name: name, publicKey: publicKey, attributes: attributes)
            } catch {
                return nil
            }
        }
        secrets.append(contentsOf: wrapped)
    }

    /// Saves a public key.
    /// - Parameters:
    ///   - key: The data representation key to save.
    ///   - name: A user-facing name for the key.
    ///   - attributes: Attributes of the key.
    /// - Note: Despite the name, the "Data" of the key is _not_ actual key material. This is an opaque data representation that the SEP can manipulate.
    @discardableResult
    func saveKey(_ key: Data, name: String, attributes: Attributes) throws -> String {
        let attributes = try JSONEncoder().encode(attributes)
        let id = UUID().uuidString
        let keychainAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: Constants.keyTag,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccount: id,
            kSecValueData: key,
            kSecAttrLabel: name,
            kSecAttrGeneric: attributes
        ])
        let status = SecItemAdd(keychainAttributes, nil)
        if status != errSecSuccess {
            throw KeychainError(statusCode: status)
        }
        return id
    }
    
}

extension SecureEnclave.Store {

    enum Constants {
        static let keyClass = kSecClassGenericPassword as String
        static let keyTag = Data("com.maxgoedjen.secretive.secureenclave.key".utf8)
    }
    
    struct UnsupportedAlgorithmError: Error {}
    struct MissingAttributesError: Error {}

}
