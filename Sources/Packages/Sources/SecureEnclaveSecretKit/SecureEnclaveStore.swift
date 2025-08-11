import Foundation
import Observation
import Security
import CryptoKit
@preconcurrency import LocalAuthentication
import SecretKit
import os
import Common

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave.
    @Observable public final class Store: SecretStoreModifiable {

        public var isAvailable: Bool {
            CryptoKit.SecureEnclave.isAvailable
        }
        public let id = UUID()
        public let name = String(localized: "secure_enclave")
        public var secrets: [Secret] {
            _secrets.lockedValue
        }
        private let _secrets: OSAllocatedUnfairLock<[Secret]> = .init(uncheckedState: [])

        private let persistedAuthenticationContexts: OSAllocatedUnfairLock<[Secret: PersistentAuthenticationContext]> = .init(uncheckedState: [:])

        /// Initializes a Store.
        public init() {
            Task {
                for await _ in DistributedNotificationCenter.default().notifications(named: .secretStoreUpdated) {
                    await reloadSecretsInternal(notifyAgent: false)
                }
            }
            loadSecrets()
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
        
        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) throws -> Data {
            var context: LAContext
            if let existing = persistedAuthenticationContexts.lockedValue[secret], existing.valid {
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

        public func existingPersistedAuthenticationContext(secret: Secret) -> PersistedAuthenticationContext? {
            guard let persisted = persistedAuthenticationContexts.lockedValue[secret], persisted.valid else { return nil }
            return persisted
        }

        public func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) throws {
            let newContext = LAContext()
            newContext.touchIDAuthenticationAllowableReuseDuration = duration
            newContext.localizedCancelTitle = String(localized: "auth_context_request_deny_button")

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .spellOut
            formatter.allowedUnits = [.hour, .minute, .day]

            if let durationString = formatter.string(from: duration) {
                newContext.localizedReason = String(localized: "auth_context_persist_for_duration_\(secret.name)_\(durationString)")
            } else {
                newContext.localizedReason = String(localized: "auth_context_persist_for_duration_unknown_\(secret.name)")
            }
            newContext.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: newContext.localizedReason) { [weak self] success, _ in
                guard success, let self else { return }
                let context = PersistentAuthenticationContext(secret: secret, context: newContext, duration: duration)
                self.persistedAuthenticationContexts.withLock {
                    $0[secret] = context
                }
            }
        }

        public func reloadSecrets() async {
            await reloadSecretsInternal(notifyAgent: false)
        }

    }

}

extension SecureEnclave.Store {

    /// Reloads all secrets from the store.
    /// - Parameter notifyAgent: A boolean indicating whether a distributed notification should be posted, notifying other processes (ie, the SecretAgent) to reload their stores as well.
    private func reloadSecretsInternal(notifyAgent: Bool = true) async {
        let before = secrets
        _secrets.withLock {
            $0.removeAll()
        }
        loadSecrets()
        if secrets != before {
            NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
            if notifyAgent {
                DistributedNotificationCenter.default().postNotificationName(.secretStoreUpdated, object: nil, deliverImmediately: true)
            }
        }
    }

    /// Loads all secrets from the store.
    private func loadSecrets() {
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
        _secrets.withLock {
            $0.append(contentsOf: wrapped)
        }
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

extension SecureEnclave {

    /// A context describing a persisted authentication.
    private final class PersistentAuthenticationContext: PersistedAuthenticationContext {

        /// The Secret to persist authentication for.
        let secret: Secret
        /// The LAContext used to authorize the persistent context.
        nonisolated(unsafe) let context: LAContext
        /// An expiration date for the context.
        /// - Note -  Monotonic time instead of Date() to prevent people setting the clock back.
        let monotonicExpiration: UInt64

        /// Initializes a context.
        /// - Parameters:
        ///   - secret: The Secret to persist authentication for.
        ///   - context: The LAContext used to authorize the persistent context.
        ///   - duration: The duration of the authorization context, in seconds.
        init(secret: Secret, context: LAContext, duration: TimeInterval) {
            self.secret = secret
            self.context = context
            let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
            self.monotonicExpiration = clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds)
        }

        /// A boolean describing whether or not the context is still valid.
        var valid: Bool {
            clock_gettime_nsec_np(CLOCK_MONOTONIC) < monotonicExpiration
        }

        var expiration: Date {
            let remainingNanoseconds = monotonicExpiration - clock_gettime_nsec_np(CLOCK_MONOTONIC)
            let remainingInSeconds = Measurement(value: Double(remainingNanoseconds), unit: UnitDuration.nanoseconds).converted(to: .seconds).value
            return Date(timeIntervalSinceNow: remainingInSeconds)
        }
    }

}
