import Foundation
import Security
import CryptoTokenKit

// TODO: Might need to split this up into "sub-stores?"
// ie, each token has its own Store.
extension SmartCard {

    public class Store: SecretStore {

        // TODO: Read actual smart card name, eg "YubiKey 5c"
        @Published public var isAvailable: Bool = false
        public let id = UUID()
        public let name = NSLocalizedString("Smart Card", comment: "Smart Card")
        @Published public fileprivate(set) var secrets: [Secret] = []
        fileprivate let watcher = TKTokenWatcher()
        fileprivate var tokenID: String?

        public init() {
            tokenID = watcher.tokenIDs.filter { !$0.contains("setoken") }.first
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

        public func sign(data: Data, with secret: SecretType) throws -> Data {
            guard let tokenID = tokenID else { fatalError() }
            let attributes = [
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrTokenID: tokenID,
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
            return signature as Data
        }

    }

}

extension SmartCard.Store {

    fileprivate func smartcardRemoved(for tokenID: String? = nil) {
        self.tokenID = nil
        reloadSecrets()
    }

    fileprivate func reloadSecrets() {
        DispatchQueue.main.async {
            self.isAvailable = self.tokenID != nil
            self.secrets.removeAll()
            self.loadSecrets()
        }
    }

    fileprivate func loadSecrets() {
        guard let tokenID = tokenID else { return }
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

extension SmartCard {

    public struct KeychainError: Error {
        public let statusCode: OSStatus
    }

    public struct SigningError: Error {
        public let error: SecurityError?
    }

}

extension SmartCard {

    public typealias SecurityError = Unmanaged<CFError>

}
