import Foundation
import Observation
import Security
import CryptoKit
@preconcurrency import LocalAuthentication
import SecretKit
import os

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave using CryptoKit API.
    @Observable final class CryptoKitStore: SecretStoreModifiable {

        @MainActor var secrets: [Secret] = []
        var isAvailable: Bool {
            CryptoKit.SecureEnclave.isAvailable
        }
        let id = UUID()
        let name = String(localized: .secureEnclave)
        private let persistentAuthenticationHandler = PersistentAuthenticationHandler()

        /// Initializes a Store.
        @MainActor init() {
            loadSecrets()
            Task {
                for await _ in DistributedNotificationCenter.default().notifications(named: .secretStoreUpdated) {
                    reloadSecrets()
                }
            }
        }

        // MARK: - Public API
        
        // MARK: SecretStore
        
        func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) async throws -> Data {
            var context: LAContext
            if let existing = await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret) {
                context = existing.context
            } else {
                let newContext = LAContext()
                newContext.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
                context = newContext
            }
            context.localizedReason = String(localized: "auth_context_request_signature_description_\(provenance.origin.displayName)_\(secret.name)")

            let queryAttributes = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrService: SecureEnclave.Constants.keyTag,
                kSecUseDataProtectionKeychain: true,
                kSecAttrAccount: String(decoding: secret.id, as: UTF8.self),
                kSecReturnAttributes: true,
                kSecReturnData: true
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
                let key = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
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

        func verify(signature: Data, for data: Data, with secret: Secret) throws -> Bool {
            let context = LAContext()
            context.localizedReason = String(localized: "auth_context_request_verify_description_\(secret.name)")
            context.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
            let attributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrKeyType: Constants.keyClass,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
                kSecUseAuthenticationContext: context,
                kSecReturnRef: true
                ])
            var verifyError: SecurityError?
            var untyped: CFTypeRef?
            let status = SecItemCopyMatching(attributes, &untyped)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            let verified = SecKeyVerifySignature(key, .ecdsaSignatureMessageX962SHA256, data as CFData, signature as CFData, &verifyError)
            if !verified, let verifyError {
                if verifyError.takeUnretainedValue() ~= .verifyError {
                    return false
                } else {
                    throw SigningError(error: verifyError)
                }
            }
            return verified
        }

        func existingPersistedAuthenticationContext(secret: Secret) async -> PersistedAuthenticationContext? {
            await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret)
        }

        func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) async throws {
            try await persistentAuthenticationHandler.persistAuthentication(secret: secret, forDuration: duration)
        }

        @MainActor func reloadSecrets() {
            secrets.removeAll()
            loadSecrets()
        }

        // MARK: SecretStoreModifiable
        
        func create(name: String, attributes: Attributes) async throws {
            var accessError: SecurityError?
            let flags: SecAccessControlCreateFlags = switch attributes.authentication {
            case .notRequired:
                []
            case .presenceRequired:
                    .userPresence
            case .biometryCurrent:
                    .biometryCurrentSet
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
            switch (attributes.keyType.algorithm, attributes.keyType.size) {
            case (.ecdsa, 256):
                let created = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(accessControl: access!)
                dataRep = created.dataRepresentation
            case (.mldsa, 65):
                guard #available(macOS 26.0, *) else { throw Attributes.UnsupportedOptionError() }
                let created = try CryptoKit.SecureEnclave.MLDSA65.PrivateKey(accessControl: access!)
                dataRep = created.dataRepresentation
            case (.mldsa, 87):
                guard #available(macOS 26.0, *) else { throw Attributes.UnsupportedOptionError() }
                let created = try CryptoKit.SecureEnclave.MLDSA87.PrivateKey(accessControl: access!)
                dataRep = created.dataRepresentation
            default:
                throw Attributes.UnsupportedOptionError()
            }
            try saveKey(dataRep, name: name, attributes: attributes)
            await reloadSecrets()
        }

        func delete(secret: Secret) async throws {
            let deleteAttributes = KeychainDictionary([
                kSecClass: Constants.keyClass,
                kSecAttrService: SecureEnclave.Constants.keyTag,
                kSecUseDataProtectionKeychain: true,
                kSecAttrAccount: String(decoding: secret.id, as: UTF8.self)
            ])
            let status = SecItemDelete(deleteAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            await reloadSecrets()
        }

        func update(secret: Secret, name: String, attributes: Attributes) async throws {
            let updateQuery = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id as CFData
            ])

            let updatedAttributes = KeychainDictionary([
                kSecAttrLabel: name,
            ])

            let status = SecItemUpdate(updateQuery, updatedAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            await reloadSecrets()
        }
        
        var supportedKeyTypes: [KeyType] {
            [
                .init(algorithm: .ecdsa, size: 256),
                .init(algorithm: .mldsa, size: 65),
                .init(algorithm: .mldsa, size: 87),
            ]
        }

    }

}

extension SecureEnclave.CryptoKitStore {

    /// Loads all secrets from the store.
    @MainActor private func loadSecrets() {
        let queryAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: SecureEnclave.Constants.keyTag,
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
    private func saveKey(_ key: Data, name: String, attributes: Attributes) throws {
        let attributes = try JSONEncoder().encode(attributes)
        let keychainAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: SecureEnclave.Constants.keyTag,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrAccount: UUID().uuidString,
            kSecValueData: key,
            kSecAttrLabel: name,
            kSecAttrGeneric: attributes
        ])
        let status = SecItemAdd(keychainAttributes, nil)
        if status != errSecSuccess {
            throw KeychainError(statusCode: status)
        }
    }
    
}

extension SecureEnclave.CryptoKitStore {

    enum Constants {
        static let keyClass = kSecClassGenericPassword as String
    }
    
    fileprivate protocol CryptoKitKey: Sendable {
        init(dataRepresentation: Data, authenticationContext: LAContext?) throws
        var dataRepresentation: Data { get }
    }

    
    struct UnsupportedAlgorithmError: Error {}
    struct MissingAttributesError: Error {}

}
