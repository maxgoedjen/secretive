import Foundation
import Combine
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension SmartCard {

    /// An implementation of Store backed by a Smart Card.
    public final class Store: SecretStore {

        @Published public var isAvailable: Bool = false
        public let id = UUID()
        public private(set) var name = String(localized: "smart_card")
        @Published public private(set) var secrets: [Secret] = []
        private let watcher = TKTokenWatcher()
        private var tokenID: String?

        /// Initializes a Store.
        public init() {
            tokenID = watcher.nonSecureEnclaveTokens.first
            watcher.setInsertionHandler { [reload = reloadSecretsInternal] string in
                guard self.tokenID == nil else { return }
                guard !string.contains("setoken") else { return }

                self.tokenID = string
                DispatchQueue.main.async {
                    reload()
                }
                self.watcher.addRemovalHandler(self.smartcardRemoved, forTokenID: string)
            }
            if let tokenID = tokenID {
                self.isAvailable = true
                self.watcher.addRemovalHandler(self.smartcardRemoved, forTokenID: tokenID)
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
            guard let tokenID = tokenID else { fatalError() }
            let context = LAContext()
            context.localizedReason = "sign a request from \"\(provenance.origin.displayName)\" using secret \"\(secret.name)\""
            context.localizedCancelTitle = "Deny"
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

    @Sendable private func reloadSecretsInternal() {
        self.isAvailable = self.tokenID != nil
        let before = self.secrets
        self.secrets.removeAll()
        self.loadSecrets()
        if self.secrets != before {
            NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
        }
    }

    /// Resets the token ID and reloads secrets.
    /// - Parameter tokenID: The ID of the token that was removed.
    private func smartcardRemoved(for tokenID: String? = nil) {
        self.tokenID = nil
        reloadSecrets()
    }

    /// Loads all secrets from the store.
    private func loadSecrets() {
        guard let tokenID = tokenID else { return }

        let fallbackName = String(localized: "smart_card")
        if let driverName = watcher.tokenInfo(forTokenID: tokenID)?.driverName {
            name = driverName
        } else {
            name = fallbackName
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
            let name = $0[kSecAttrLabel] as? String ?? "Unnamed"
            let tokenID = $0[kSecAttrApplicationLabel] as! Data
            let algorithm = Algorithm(secAttr: $0[kSecAttrKeyType] as! NSNumber)
            let keySize = $0[kSecAttrKeySizeInBits] as! Int
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeySecRef = SecKeyCopyPublicKey(publicKeyRef)!
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeySecRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            return SmartCard.Secret(id: tokenID, name: name, algorithm: algorithm, keySize: keySize, publicKey: publicKey)
        }
        secrets.append(contentsOf: wrapped)
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
        context.localizedReason = "encrypt data using secret \"\(secret.name)\""
        context.localizedCancelTitle = "Deny"
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
        guard let tokenID = tokenID else { fatalError() }
        let context = LAContext()
        context.localizedReason = "decrypt data using secret \"\(secret.name)\""
        context.localizedCancelTitle = "Deny"
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
