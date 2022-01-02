import Foundation
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

// TODO: Might need to split this up into "sub-stores?"
// ie, each token has its own Store.
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

        public func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> SignedData {
            guard let tokenID = tokenID else { fatalError() }
            let context = LAContext()
            context.localizedReason = "sign a request from \"\(provenance.origin.displayName)\" using secret \"\(secret.name)\""
            context.localizedCancelTitle = "Deny"
            let attributes = [
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrTokenID: tokenID,
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
            let signatureAlgorithm: SecKeyAlgorithm
            switch (secret.algorithm, secret.keySize) {
            case (.ellipticCurve, 256):
                signatureAlgorithm = .ecdsaSignatureMessageX962SHA256
            case (.ellipticCurve, 384):
                signatureAlgorithm = .ecdsaSignatureMessageX962SHA384
            default:
                fatalError()
            }
            guard let signature = SecKeyCreateSignature(key, signatureAlgorithm, data as CFData, &signError) else {
                throw SigningError(error: signError)
            }
            return SignedData(data: signature as Data, requiredAuthentication: false)
        }

        public func persistAuthentication(secret: SmartCard.Secret, forDuration: TimeInterval) throws {
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

    /// Reloads all secrets from the store.
    private func reloadSecrets() {
        DispatchQueue.main.async {
            self.isAvailable = self.tokenID != nil
            self.secrets.removeAll()
            self.loadSecrets()
        }
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

        let attributes = [
            kSecClass: kSecClassKey,
            kSecAttrTokenID: tokenID,
            kSecAttrKeyType: kSecAttrKeyTypeEC, // Restrict to EC
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
        ] as CFDictionary
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
