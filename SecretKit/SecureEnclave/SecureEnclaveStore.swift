import Foundation
import Security
import CryptoTokenKit
import LocalAuthentication

extension SecureEnclave {

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

        private var pendingAuthenticationContext: PersistentAuthenticationContext? = nil
        private var persistedAuthenticationContexts: [Secret: PersistentAuthenticationContext] = [:]

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

            var privateKey: SecKey? = nil
            var publicKey: SecKey? = nil
            let status = SecKeyGeneratePair(attributes, &publicKey, &privateKey)
            guard privateKey != nil, let pk = publicKey else {
                throw KeychainError(statusCode: status)
            }
            try savePublicKey(pk, name: name)
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
            // TODO: RESTORE
            if let existing = persistedAuthenticationContexts[secret], existing.valid {
                context = existing.context
            } else {
                let newContext = LAContext()
                newContext.localizedCancelTitle = "Deny"
                // TODO: FIX
                pendingAuthenticationContext = PersistentAuthenticationContext(secret: secret, context: newContext, expiration: Date(timeIntervalSinceNow: 100))
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
            // Since there's now way to inspect SecAccessControl to determine.
            let requiredAuthentication = signatureDuration > Constants.unauthenticatedThreshold

            return SignedData(data: signature as Data, requiredAuthentication: requiredAuthentication)
        }

        public func persistAuthentication(secret: Secret, forDuration: TimeInterval) throws {
            guard secret == pendingAuthenticationContext?.secret else { throw AuthenticationPersistenceError() }
            persistedAuthenticationContexts[secret] = pendingAuthenticationContext
            pendingAuthenticationContext = nil
        }

    }

}

extension SecureEnclave.Store {

    private func reloadSecrets(notify: Bool = true) {
        secrets.removeAll()
        loadSecrets()
        if notify {
            DistributedNotificationCenter.default().post(name: .secretStoreUpdated, object: nil)
        }
    }

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

    public struct KeychainError: Error {
        public let statusCode: OSStatus
    }

    public struct SigningError: Error {
        public let error: SecurityError?
    }

    public struct AuthenticationPersistenceError: Error {
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

    private struct PersistentAuthenticationContext {

        let secret: Secret
        let context: LAContext
        // TODO: monotonic time instead of Date() to prevent people setting the clock back.
        let expiration: Date

        var valid: Bool {
            Date() < expiration
        }
    }

}
