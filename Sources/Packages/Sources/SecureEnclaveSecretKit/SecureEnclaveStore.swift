import Foundation
import Observation
import Security
import CryptoKit
import LocalAuthentication
import SecretKit

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave.
    @Observable public final class Store: SecretStoreModifiable {

        @MainActor public var secrets: [Secret] = []
        public var isAvailable: Bool {
            CryptoKit.SecureEnclave.isAvailable
        }
        public let id = UUID()
        public let name = String(localized: "secure_enclave")
        private let persistentAuthenticationHandler = PersistentAuthenticationHandler()

        /// Initializes a Store.
        @MainActor public init() {
            loadSecrets()
            Task {
                for await _ in DistributedNotificationCenter.default().notifications(named: .secretStoreUpdated) {
                    await reloadSecretsInternal(notifyAgent: false)
                }
            }
        }

        // MARK: Public API

        public func create(name: String, requiresAuthentication: Bool) async throws {
            var accessError: SecurityError?
            let flags: SecAccessControlCreateFlags
            if requiresAuthentication {
                flags = [.privateKeyUsage, .userPresence]
            } else {
                flags = .privateKeyUsage
            }
            let access =
                SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                flags,
                                                &accessError) as Any
            if let error = accessError {
                throw error.takeRetainedValue() as Error
            }

            let attributes = KeychainDictionary([
                kSecAttrLabel: name,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: Constants.keyTag,
                kSecPrivateKeyAttrs: [
                    kSecAttrIsPermanent: true,
                    kSecAttrAccessControl: access
                ]
            ])

            var createKeyError: SecurityError?
            let keypair = SecKeyCreateRandomKey(attributes, &createKeyError)
            if let error = createKeyError {
                throw error.takeRetainedValue() as Error
            }
            guard let keypair = keypair, let publicKey = SecKeyCopyPublicKey(keypair) else {
                throw KeychainError(statusCode: nil)
            }
            try savePublicKey(publicKey, name: name)
            await reloadSecretsInternal()
        }

        public func delete(secret: Secret) async throws {
            let deleteAttributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id as CFData
            ])
            let status = SecItemDelete(deleteAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            await reloadSecretsInternal()
        }

        public func update(secret: Secret, name: String) async throws {
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
            await reloadSecretsInternal()
        }
        
        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) async throws -> Data {
            let context: LAContext
            if let existing = await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret) {
                context = existing.context
            } else {
                let newContext = LAContext()
                newContext.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
                context = newContext
            }
            context.localizedReason = String(localized: "auth_context_request_signature_description_\(provenance.origin.displayName)_\(secret.name)")
            let attributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: Constants.keyTag,
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

        public func verify(signature: Data, for data: Data, with secret: Secret) throws -> Bool {
            let context = LAContext()
            context.localizedReason = String(localized: "auth_context_request_verify_description_\(secret.name)")
            context.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
            let attributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: Constants.keyTag,
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

        public func existingPersistedAuthenticationContext(secret: Secret) async -> PersistedAuthenticationContext? {
            await persistentAuthenticationHandler.existingPersistedAuthenticationContext(secret: secret)
        }

        public func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) async throws {
            try await persistentAuthenticationHandler.persistAuthentication(secret: secret, forDuration: duration)
        }

        public func reloadSecrets() async {
            await reloadSecretsInternal(notifyAgent: false)
        }

    }

}

extension SecureEnclave.Store {

    /// Reloads all secrets from the store.
    /// - Parameter notifyAgent: A boolean indicating whether a distributed notification should be posted, notifying other processes (ie, the SecretAgent) to reload their stores as well.
    @MainActor private func reloadSecretsInternal(notifyAgent: Bool = true) async {
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
        let publicAttributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrKeyType: SecureEnclave.Constants.keyType,
            kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ])
        var publicUntyped: CFTypeRef?
        SecItemCopyMatching(publicAttributes, &publicUntyped)
        guard let publicTyped = publicUntyped as? [[CFString: Any]] else { return }
        let privateAttributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrKeyType: SecureEnclave.Constants.keyType,
            kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ])
        var privateUntyped: CFTypeRef?
        SecItemCopyMatching(privateAttributes, &privateUntyped)
        guard let privateTyped = privateUntyped as? [[CFString: Any]] else { return }
        let privateMapped = privateTyped.reduce(into: [:] as [Data: [CFString: Any]]) { partialResult, next in
            let id = next[kSecAttrApplicationLabel] as! Data
            partialResult[id] = next
        }
        let authNotRequiredAccessControl: SecAccessControl =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                            [.privateKeyUsage],
                                            nil)!

        let wrapped: [SecureEnclave.Secret] = publicTyped.map {
            let name = $0[kSecAttrLabel] as? String ?? String(localized: "unnamed_secret")
            let id = $0[kSecAttrApplicationLabel] as! Data
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeyRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            let privateKey = privateMapped[id]
            let requiresAuth: Bool
            if let authRequirements = privateKey?[kSecAttrAccessControl] {
                // Unfortunately we can't inspect the access control object directly, but it does behave predicatable with equality.
                requiresAuth = authRequirements as! SecAccessControl != authNotRequiredAccessControl
            } else {
                requiresAuth = false
            }
            return SecureEnclave.Secret(id: id, name: name, requiresAuthentication: requiresAuth, publicKey: publicKey)
        }
        secrets.append(contentsOf: wrapped)
    }

    /// Saves a public key.
    /// - Parameters:
    ///   - publicKey: The public key to save.
    ///   - name: A user-facing name for the key.
    private func savePublicKey(_ publicKey: SecKey, name: String) throws {
        let attributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrKeyType: SecureEnclave.Constants.keyType,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
            kSecValueRef: publicKey,
            kSecAttrIsPermanent: true,
            kSecReturnData: true,
            kSecAttrLabel: name
            ])
        let status = SecItemAdd(attributes, nil)
        if status != errSecSuccess {
            throw KeychainError(statusCode: status)
        }
    }

}

extension SecureEnclave {

    enum Constants {
        static let keyTag = Data("com.maxgoedjen.secretive.secureenclave.key".utf8)
        static let keyType = kSecAttrKeyTypeECSECPrimeRandom as String
        static let unauthenticatedThreshold: TimeInterval = 0.05
    }

}
