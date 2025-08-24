import Foundation
import Observation
import Security
import CryptoKit
import LocalAuthentication
import SecretKit

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave.
    @Observable final class VanillaKeychainStore: SecretStoreModifiable {

        @MainActor var secrets: [Secret] = []
        var isAvailable: Bool {
            CryptoKit.SecureEnclave.isAvailable
        }
        let id = UUID()
        let name = String(localized: .secureEnclave)
        var supportedKeyTypes: [KeyType] {
            [KeyType(algorithm: .ecdsa, size: 256)]
        }

        private let persistentAuthenticationHandler = PersistentAuthenticationHandler()

        /// Initializes a Store.
        @MainActor init() {
            loadSecrets()
        }

        // MARK: - Public API

        // MARK: SecretStore

        func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) async throws -> Data {
            let context: LAContext
            if let existing = await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret) {
                context = existing.context
            } else {
                let newContext = LAContext()
                newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)
                context = newContext
            }
            context.localizedReason = String(localized: .authContextRequestSignatureDescription(appName: provenance.origin.displayName, secretName: secret.name))
            let attributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
                kSecUseAuthenticationContext: context,
                kSecReturnRef: true
            ])
            var untyped: CFTypeRef?
            let status = SecItemCopyMatching(attributes, &untyped)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            var signError: SecurityError?

            guard let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, data as CFData, &signError) else {
                throw SigningError(error: signError)
            }
            return signature as Data
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
            throw DeprecatedCreationStore()
        }

        func delete(secret: Secret) async throws {
            let deleteAttributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id as CFData
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


    }

}

extension SecureEnclave.VanillaKeychainStore {

    /// Loads all secrets from the store.
    @MainActor private func loadSecrets() {
        let privateAttributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrKeyType: Constants.keyType,
            kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ])
        var privateUntyped: CFTypeRef?
        SecItemCopyMatching(privateAttributes, &privateUntyped)
        guard let privateTyped = privateUntyped as? [[CFString: Any]] else { return }
        let wrapped: [SecureEnclave.Secret] = privateTyped.map {
            let name = $0[kSecAttrLabel] as? String ?? String(localized: .unnamedSecret)
            let id = $0[kSecAttrApplicationLabel] as! Data
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeySecRef = SecKeyCopyPublicKey(publicKeyRef)!
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeySecRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            return SecureEnclave.Secret(id: id, name: name, authenticationRequirement: .unknown, publicKey: publicKey)
        }
        secrets.append(contentsOf: wrapped)
    }

}

extension SecureEnclave.VanillaKeychainStore {

    public struct DeprecatedCreationStore: Error {}

}

extension SecureEnclave.VanillaKeychainStore {

    public enum Constants {
        public static let keyType = kSecAttrKeyTypeECSECPrimeRandom as String
    }

}
