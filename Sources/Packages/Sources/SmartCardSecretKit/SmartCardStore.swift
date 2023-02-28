import Foundation
import Combine
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension SmartCard {

    /// An implementation of Store backed by a Smart Card.
    public class Store: SecretStore {

        @Published public var isAvailable: Bool = false
        public let id = UUID()
        public private(set) var name = NSLocalizedString("Smart Card", comment: "Smart Card")
        @Published public private(set) var secrets: [Secret] = []
        private let watcher = TKTokenWatcher()
        private var tokenID: String?

        /// Initializes a Store.
        public init() {
            tokenID = watcher.nonSecureEnclaveTokens.first
            watcher.setInsertionHandler { string in
                guard self.tokenID == nil else { return }
                guard !string.contains("setoken") else { return }

                self.tokenID = string
                self.reloadSecrets()
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

        public func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> Data {
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
            let signatureAlgorithm: SecKeyAlgorithm
            switch (secret.algorithm, secret.keySize) {
            case (.ellipticCurve, 256):
                signatureAlgorithm = .ecdsaSignatureMessageX962SHA256
            case (.ellipticCurve, 384):
                signatureAlgorithm = .ecdsaSignatureMessageX962SHA384
            case (.rsa, 1024):
                signatureAlgorithm = .rsaSignatureMessagePKCS1v15SHA512
            case (.rsa, 2048):
                signatureAlgorithm = .rsaSignatureMessagePKCS1v15SHA512
            default:
                fatalError()
            }
            guard let signature = SecKeyCreateSignature(key, signatureAlgorithm, data as CFData, &signError) else {
                throw SigningError(error: signError)
            }
            return signature as Data
        }
        
        public func verify(data: Data, signature: Data, with secret: SecretType) throws -> Bool {
        
            let attributes = KeychainDictionary([
                kSecAttrKeyType: secret.algorithm.secAttrKeyType,
                kSecAttrKeySizeInBits: secret.keySize,
                kSecAttrKeyClass: kSecAttrKeyClassPublic
            ])
            var encryptError: SecurityError?
            var untyped: CFTypeRef? = SecKeyCreateWithData(secret.publicKey as CFData, attributes, &encryptError)
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            let signatureAlgorithm: SecKeyAlgorithm
            switch (secret.algorithm, secret.keySize) {
            case (.ellipticCurve, 256):
                signatureAlgorithm = .ecdsaSignatureMessageX962SHA256
            case (.ellipticCurve, 384):
                signatureAlgorithm = .ecdsaSignatureMessageX962SHA384
            case (.rsa, 1024):
                signatureAlgorithm = .rsaSignatureMessagePKCS1v15SHA512
            case (.rsa, 2048):
                signatureAlgorithm = .rsaSignatureMessagePKCS1v15SHA512
            default:
                fatalError()
            }
            let signature = SecKeyVerifySignature(key, signatureAlgorithm, data as CFData, signature as CFData, &encryptError)
            if !signature {
                throw SigningError(error: encryptError)
            }
            return signature
        }
        
        public func encrypt(data: Data, with secret: SecretType) throws -> Data {
            let attributes = KeychainDictionary([
                kSecAttrKeyType: secret.algorithm.secAttrKeyType,
                kSecAttrKeySizeInBits: secret.keySize,
                kSecAttrKeyClass: kSecAttrKeyClassPublic
            ])
            var encryptError: SecurityError?
            let untyped: CFTypeRef? = SecKeyCreateWithData(secret.publicKey as CFData, attributes, &encryptError)
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            let signatureAlgorithm: SecKeyAlgorithm
            switch (secret.algorithm, secret.keySize) {
            case (.ellipticCurve, 256):
                signatureAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
            case (.ellipticCurve, 384):
                signatureAlgorithm = .eciesEncryptionCofactorVariableIVX963SHA256AESGCM
            case (.rsa, 1024):
                signatureAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
            case (.rsa, 2048):
                signatureAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
            default:
                fatalError()
            }
            guard let signature = SecKeyCreateEncryptedData(key, signatureAlgorithm, data as CFData, &encryptError) else {
                throw SigningError(error: encryptError)
            }
            return signature as Data
        }
        
        public func decrypt(data: Data, with secret: SecretType) throws -> Data {
            guard let tokenID = tokenID else { fatalError() }
            let context = LAContext()
            context.localizedReason = "decrypt a file using secret \"\(secret.name)\""
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
            let signatureAlgorithm: SecKeyAlgorithm
            switch (secret.algorithm, secret.keySize) {
            case (.ellipticCurve, 256):
                signatureAlgorithm = .eciesEncryptionStandardX963SHA256AESGCM
            case (.ellipticCurve, 384):
                signatureAlgorithm = .eciesEncryptionStandardX963SHA384AESGCM
            case (.rsa, 1024):
                signatureAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
            case (.rsa, 2048):
                signatureAlgorithm = .rsaEncryptionOAEPSHA512AESGCM
            default:
                fatalError()
            }
            guard let signature = SecKeyCreateDecryptedData(key, signatureAlgorithm, data as CFData, &encryptError) else {
                throw SigningError(error: encryptError)
            }
            return signature as Data
        }

        public func existingPersistedAuthenticationContext(secret: SmartCard.Secret) -> PersistedAuthenticationContext? {
            nil
        }

        public func persistAuthentication(secret: SmartCard.Secret, forDuration: TimeInterval) throws {
        }

        /// Reloads all secrets from the store.
        public func reloadSecrets() {
            DispatchQueue.main.async {
                self.isAvailable = self.tokenID != nil
                let before = self.secrets
                self.secrets.removeAll()
                self.loadSecrets()
                if self.secrets != before {
                    NotificationCenter.default.post(name: .secretStoreReloaded, object: self)
                }
            }
        }

    }

}

extension SmartCard.Store {

    /// Resets the token ID and reloads secrets.
    /// - Parameter tokenID: The ID of the token that was removed.
    private func smartcardRemoved(for tokenID: String? = nil) {
        self.tokenID = nil
        reloadSecrets()
    }

    /// Loads all secrets from the store.
    private func loadSecrets() {
        guard let tokenID = tokenID else { return }

        let fallbackName = NSLocalizedString("Smart Card", comment: "Smart Card")
        if #available(macOS 12.0, *) {
            if let driverName = watcher.tokenInfo(forTokenID: tokenID)?.driverName {
                name = driverName
            } else {
                name = fallbackName
            }
        } else {
            // Hack to read name if there's only one smart card
            let slotNames = TKSmartCardSlotManager().slotNames
            if watcher.nonSecureEnclaveTokens.count == 1 && slotNames.count == 1 {
                name = slotNames.first!
            } else {
                name = fallbackName
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
        let wrapped: [SmartCard.Secret] = typed.map {
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

extension TKTokenWatcher {

    /// All available tokens, excluding the Secure Enclave.
    fileprivate var nonSecureEnclaveTokens: [String] {
        tokenIDs.filter { !$0.contains("setoken") }
    }

}

extension SmartCard {

    /// A wrapper around an error code reported by a Keychain API.
    public struct KeychainError: Error {
        /// The status code involved.
        public let statusCode: OSStatus
    }

    /// A signing-related error.
    public struct SigningError: Error {
        /// The underlying error reported by the API, if one was returned.
        public let error: SecurityError?
    }

}

extension SmartCard {

    public typealias SecurityError = Unmanaged<CFError>

}
