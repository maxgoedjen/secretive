import Foundation
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension SecureEnclave {

    /// An implementation of Store backed by the Secure Enclave.
    public class Store: SecretStoreModifiable {

        public var isAvailable: Bool {
            // For some reason, as of build time, CryptoKit.SecureEnclave.isAvailable always returns false
            // error msg "Received error sending GET UNIQUE DEVICE command"
            // Verify it with TKTokenWatcher manually.
            TKTokenWatcher().tokenIDs.contains("com.apple.setoken")
        }
        public let id = UUID()
        public let name = NSLocalizedString("Secure Enclave", comment: "Secure Enclave")
        @Published public private(set) var secrets: [Secret] = []

        private var persistedAuthenticationContexts: [Secret: PersistentAuthenticationContext] = [:]

        /// Initializes a Store.
        public init() {
            DistributedNotificationCenter.default().addObserver(forName: .secretStoreUpdated, object: nil, queue: .main) { _ in
                self.reloadSecrets(notify: false)
            }
            loadSecrets()
        }

        // MARK: Public API

        public func create(name: String, requiresAuthentication: Bool) throws {
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

            let attributes = [
                kSecAttrLabel: name,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: Constants.keyTag,
                kSecPrivateKeyAttrs: [
                    kSecAttrIsPermanent: true,
                    kSecAttrAccessControl: access
                ]
            ] as CFDictionary

            var createKeyError: SecurityError?
            let keypair = SecKeyCreateRandomKey(attributes, &createKeyError)
            if let error = createKeyError {
                throw error.takeRetainedValue() as Error
            }
            guard let keypair = keypair, let publicKey = SecKeyCopyPublicKey(keypair) else {
                throw KeychainError(statusCode: nil)
            }
            try savePublicKey(publicKey, name: name)
            reloadSecrets()
        }

        public func delete(secret: Secret) throws {
            let deleteAttributes = [
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id as CFData
            ] as CFDictionary
            let status = SecItemDelete(deleteAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            reloadSecrets()
        }

        public func update(secret: Secret, name: String) throws {
            let updateQuery = [
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id as CFData
            ] as CFDictionary

            let updatedAttributes = [
                kSecAttrLabel: name,
            ] as CFDictionary

            let status = SecItemUpdate(updateQuery, updatedAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
            reloadSecrets()
        }
        
        public func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> SignedData {
            let context: LAContext
            if let existing = persistedAuthenticationContexts[secret], existing.valid {
                context = existing.context
            } else {
                let newContext = LAContext()
                newContext.localizedCancelTitle = "Deny"
                context = newContext
            }
            context.localizedReason = "sign a request from \"\(provenance.origin.displayName)\" using secret \"\(secret.name)\""
            let attributes = [
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: Constants.keyTag,
                kSecUseAuthenticationContext: context,
                kSecReturnRef: true
                ] as CFDictionary
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

            let signingStartTime = Date()
            guard let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, data as CFData, &signError) else {
                throw SigningError(error: signError)
            }
            let signatureDuration = Date().timeIntervalSince(signingStartTime)
            // Hack to determine if the user had to authenticate to sign.
            // Since there's now way to inspect SecAccessControl to determine (afaict).
            let requiredAuthentication = signatureDuration > Constants.unauthenticatedThreshold

            return SignedData(data: signature as Data, requiredAuthentication: requiredAuthentication)
        }

        public func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) throws {
            let newContext = LAContext()
            newContext.touchIDAuthenticationAllowableReuseDuration = duration
            newContext.localizedCancelTitle = "Deny"

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .spellOut
            formatter.allowedUnits = [.hour, .minute, .day]

            if let durationString = formatter.string(from: duration) {
                newContext.localizedReason = "unlock secret \"\(secret.name)\" for \(durationString)"
            } else {
                newContext.localizedReason = "unlock secret \"\(secret.name)\""
            }
            newContext.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: newContext.localizedReason) { [weak self] success, _ in
                guard success else { return }
                let context = PersistentAuthenticationContext(secret: secret, context: newContext, duration: duration)
                self?.persistedAuthenticationContexts[secret] = context
            }
        }

    }

}

extension SecureEnclave.Store {

    /// Reloads all secrets from the store.
    /// - Parameter notify: A boolean indicating whether a distributed notification should be posted, notifying other processes (ie, the SecretAgent) to reload their stores as well.
    private func reloadSecrets(notify: Bool = true) {
        secrets.removeAll()
        loadSecrets()
        if notify {
            DistributedNotificationCenter.default().post(name: .secretStoreUpdated, object: nil)
        }
    }

    /// Loads all secrets from the store.
    private func loadSecrets() {
        let attributes = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: SecureEnclave.Constants.keyType,
            kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ] as CFDictionary
        var untyped: CFTypeRef?
        SecItemCopyMatching(attributes, &untyped)
        guard let typed = untyped as? [[CFString: Any]] else { return }
        let wrapped: [SecureEnclave.Secret] = typed.map {
            let name = $0[kSecAttrLabel] as? String ?? "Unnamed"
            let id = $0[kSecAttrApplicationLabel] as! Data
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeyRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            return SecureEnclave.Secret(id: id, name: name, publicKey: publicKey)
        }
        secrets.append(contentsOf: wrapped)
    }

    /// Saves a public key.
    /// - Parameters:
    ///   - publicKey: The public key to save.
    ///   - name: A user-facing name for the key.
    private func savePublicKey(_ publicKey: SecKey, name: String) throws {
        let attributes = [
            kSecClass: kSecClassKey,
            kSecAttrKeyType: SecureEnclave.Constants.keyType,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrApplicationTag: SecureEnclave.Constants.keyTag,
            kSecValueRef: publicKey,
            kSecAttrIsPermanent: true,
            kSecReturnData: true,
            kSecAttrLabel: name
            ] as CFDictionary
        let status = SecItemAdd(attributes, nil)
        if status != errSecSuccess {
            throw SecureEnclave.KeychainError(statusCode: status)
        }
    }

}

extension SecureEnclave {

    /// A wrapper around an error code reported by a Keychain API.
    public struct KeychainError: Error {
        /// The status code involved, if one was reported.
        public let statusCode: OSStatus?
    }

    /// A signing-related error.
    public struct SigningError: Error {
        /// The underlying error reported by the API, if one was returned.
        public let error: SecurityError?
    }

}

extension SecureEnclave {

    public typealias SecurityError = Unmanaged<CFError>

}

extension SecureEnclave {

    enum Constants {
        static let keyTag = "com.maxgoedjen.secretive.secureenclave.key".data(using: .utf8)! as CFData
        static let keyType = kSecAttrKeyTypeECSECPrimeRandom
        static let unauthenticatedThreshold: TimeInterval = 0.05
    }

}

extension SecureEnclave {

    /// A context describing a persisted authentication.
    private struct PersistentAuthenticationContext {

        /// The Secret to persist authentication for.
        let secret: Secret
        /// The LAContext used to authorize the persistent context.
        let context: LAContext
        /// An expiration date for the context.
        /// - Note -  Monotonic time instead of Date() to prevent people setting the clock back.
        let expiration: UInt64

        /// Initializes a context.
        /// - Parameters:
        ///   - secret: The Secret to persist authentication for.
        ///   - context: The LAContext used to authorize the persistent context.
        ///   - duration: The duration of the authorization context, in seconds.
        init(secret: Secret, context: LAContext, duration: TimeInterval) {
            self.secret = secret
            self.context = context
            let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
            self.expiration = clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds)
        }

        /// A boolean describing whether or not the context is still valid.
        var valid: Bool {
            clock_gettime_nsec_np(CLOCK_MONOTONIC) < expiration
        }
    }

}
