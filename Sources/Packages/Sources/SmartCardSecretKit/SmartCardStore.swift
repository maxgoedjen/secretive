import Foundation
import os
import Observation
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension SmartCard {
    
    private struct State {
        var isAvailable = false
        var name = String(localized: "smart_card")
        var secrets: [Secret] = []
        let watcher = TKTokenWatcher()
        var tokenID: String? = nil
    }

    /// An implementation of Store backed by a Smart Card.
    @Observable public final class Store: SecretStore {

        private let state: OSAllocatedUnfairLock<State> = .init(uncheckedState: .init())
        public var isAvailable: Bool {
            state.withLock { $0.isAvailable }
        }

        public let id = UUID()
        public var name: String {
            state.withLock { $0.name }
        }
        public var secrets: [Secret] {
            state.withLock { $0.secrets }
        }

        /// Initializes a Store.
        public init() {
            state.withLock { state in
                if let tokenID = state.tokenID {
                    state.isAvailable = true
                    state.watcher.addRemovalHandler(self.smartcardRemoved, forTokenID: tokenID)
                }
                state.watcher.setInsertionHandler { id in
                    // Setting insertion handler will cause it to be called immediately.
                    // Make a thread jump so we don't hit a recursive lock attempt.
                    Task {
                        self.smartcardInserted(for: id)
                    }
                }
            }
            loadSecrets()
        }

        // MARK: Public API

        public func create(name: String) throws {
            fatalError("Keys must be created on the smart card.")
        }

        public func delete(secret: Secret) throws {
            fatalError("Keys must be deleted on the smart card.")
        }

        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) throws -> Data {
            guard let tokenID = state.withLock({ $0.tokenID }) else { fatalError() }
            let context = LAContext()
            context.localizedReason = String(localized: "auth_context_request_signature_description_\(provenance.origin.displayName)_\(secret.name)")
            context.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
            let attributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrTokenID: tokenID,
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
            guard let signature = SecKeyCreateSignature(key, signatureAlgorithm(for: secret, allowRSA: true), data as CFData, &signError) else {
                throw SigningError(error: signError)
            }
            return signature as Data
        }
        
        public func verify(signature: Data, for data: Data, with secret: Secret) throws -> Bool {
            let attributes = KeychainDictionary([
                kSecAttrKeyType: secret.algorithm.secAttrKeyType,
                kSecAttrKeySizeInBits: secret.keySize,
                kSecAttrKeyClass: kSecAttrKeyClassPublic
            ])
            var verifyError: SecurityError?
            let untyped: CFTypeRef? = SecKeyCreateWithData(secret.publicKey as CFData, attributes, &verifyError)
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            let verified = SecKeyVerifySignature(key, signatureAlgorithm(for: secret, allowRSA: true), data as CFData, signature as CFData, &verifyError)
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
            nil
        }

        public func persistAuthentication(secret: Secret, forDuration: TimeInterval) throws {
        }

        /// Reloads all secrets from the store.
        public func reloadSecrets() {
            reloadSecretsInternal()
        }

    }

}

extension SmartCard.Store {

    private func reloadSecretsInternal() {
        let before = state.withLock {
            $0.isAvailable = $0.tokenID != nil
            let before = $0.secrets
            $0.secrets.removeAll()
            return before
        }
        self.loadSecrets()
        if self.secrets != before {
            NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
        }
    }

    /// Resets the token ID and reloads secrets.
    /// - Parameter tokenID: The ID of the token that was inserted.
    private func smartcardInserted(for tokenID: String? = nil) {
        state.withLock { state in
            guard let string = state.watcher.nonSecureEnclaveTokens.first else { return }
            guard state.tokenID == nil else { return }
            guard !string.contains("setoken") else { return }
            state.tokenID = string
            state.watcher.addRemovalHandler(self.smartcardRemoved, forTokenID: string)
            state.tokenID = string
        }
    }

    /// Resets the token ID and reloads secrets.
    /// - Parameter tokenID: The ID of the token that was removed.
    private func smartcardRemoved(for tokenID: String? = nil) {
        state.withLock {
            $0.tokenID = nil
        }
        reloadSecrets()
    }

    /// Loads all secrets from the store.
    private func loadSecrets() {
        guard let tokenID = state.withLock({ $0.tokenID }) else { return }

        let fallbackName = String(localized: "smart_card")
        state.withLock {
            if let driverName = $0.watcher.tokenInfo(forTokenID: tokenID)?.driverName  {
                $0.name = driverName
            } else {
                $0.name = fallbackName
            }
        }

        let attributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrTokenID: tokenID,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ])
        var untyped: CFTypeRef?
        SecItemCopyMatching(attributes, &untyped)
        guard let typed = untyped as? [[CFString: Any]] else { return }
        let wrapped = typed.map {
            let name = $0[kSecAttrLabel] as? String ?? String(localized: "unnamed_secret")
            let tokenID = $0[kSecAttrApplicationLabel] as! Data
            let algorithm = Algorithm(secAttr: $0[kSecAttrKeyType] as! NSNumber)
            let keySize = $0[kSecAttrKeySizeInBits] as! Int
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeySecRef = SecKeyCopyPublicKey(publicKeyRef)!
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeySecRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            return SmartCard.Secret(id: tokenID, name: name, algorithm: algorithm, keySize: keySize, publicKey: publicKey)
        }
        state.withLock {
            $0.secrets.append(contentsOf: wrapped)
        }
    }

}


// MARK: Smart Card specific encryption/decryption/verification
extension SmartCard.Store {

    /// Encrypts a payload with a specified key.
    /// - Parameters:
    ///   - data: The payload to encrypt.
    ///   - secret: The secret to encrypt with.
    /// - Returns: The encrypted data.
    /// - Warning: Encryption functions are deliberately only exposed on a library level, and are not exposed in Secretive itself to prevent users from data loss. Any pull requests which expose this functionality in the app will not be merged.
    public func encrypt(data: Data, with secret: SecretType) throws -> Data {
        let context = LAContext()
        context.localizedReason = String(localized: "auth_context_request_encrypt_description_\(secret.name)")
        context.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
        let attributes = KeychainDictionary([
            kSecAttrKeyType: secret.algorithm.secAttrKeyType,
            kSecAttrKeySizeInBits: secret.keySize,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecUseAuthenticationContext: context
        ])
        var encryptError: SecurityError?
        let untyped: CFTypeRef? = SecKeyCreateWithData(secret.publicKey as CFData, attributes, &encryptError)
        guard let untypedSafe = untyped else {
            throw KeychainError(statusCode: errSecSuccess)
        }
        let key = untypedSafe as! SecKey
        guard let signature = SecKeyCreateEncryptedData(key, encryptionAlgorithm(for: secret), data as CFData, &encryptError) else {
            throw SigningError(error: encryptError)
        }
        return signature as Data
    }

    /// Decrypts a payload with a specified key.
    /// - Parameters:
    ///   - data: The payload to decrypt.
    ///   - secret: The secret to decrypt with.
    /// - Returns: The decrypted data.
    /// - Warning: Encryption functions are deliberately only exposed on a library level, and are not exposed in Secretive itself to prevent users from data loss. Any pull requests which expose this functionality in the app will not be merged.
    public func decrypt(data: Data, with secret: SecretType) throws -> Data {
        guard let tokenID = state.withLock({ $0.tokenID }) else { fatalError() }
        let context = LAContext()
        context.localizedReason = String(localized: "auth_context_request_decrypt_description_\(secret.name)")
        context.localizedCancelTitle = String(localized: "auth_context_request_deny_button")
        let attributes = KeychainDictionary([
            kSecClass: kSecClassKey,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrApplicationLabel: secret.id as CFData,
            kSecAttrTokenID: tokenID,
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
        var encryptError: SecurityError?
        guard let signature = SecKeyCreateDecryptedData(key, encryptionAlgorithm(for: secret), data as CFData, &encryptError) else {
            throw SigningError(error: encryptError)
        }
        return signature as Data
    }

    private func encryptionAlgorithm(for secret: SecretType) -> SecKeyAlgorithm {
        switch (secret.algorithm, secret.keySize) {
        case (.ellipticCurve, 256):
            return .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
        case (.ellipticCurve, 384):
            return .eciesEncryptionCofactorVariableIVX963SHA384AESGCM
        case (.rsa, 1024), (.rsa, 2048):
            return .rsaEncryptionOAEPSHA512AESGCM
        default:
            fatalError()
        }
    }

}

extension TKTokenWatcher {

    /// All available tokens, excluding the Secure Enclave.
    fileprivate var nonSecureEnclaveTokens: [String] {
        tokenIDs.filter { !$0.contains("setoken") }
    }

}
