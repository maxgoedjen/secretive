import Foundation
import Security
import CryptoTokenKit

// TODO: Might need to split this up into "sub-stores?"
// ie, each token has its own Store.
extension SmartCard {

    public class Store: SecretStore {

        // TODO: Read actual smart card name, eg "YubiKey 5c"
        public let name = NSLocalizedString("Smart Card", comment: "Smart Card")
        @Published public fileprivate(set) var secrets: [Secret] = []
        fileprivate let watcher = TKTokenWatcher()
        fileprivate var id: String?

        public init() {
            id = watcher.tokenIDs.filter { !$0.contains("setoken") }.first
            watcher.setInsertionHandler { string in
                guard self.id == nil else { return }
                guard !string.contains("setoken") else { return }
                self.id = string
                self.reloadSecrets()
                self.watcher.addRemovalHandler(self.reloadSecrets, forTokenID: string)
            }
            if let id = id {
                self.watcher.addRemovalHandler(self.reloadSecrets, forTokenID: id)
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
            guard let id = id else { fatalError() }
            let attributes = [
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrTokenID: id,
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
            guard let signature = SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256, data as CFData, &signError) else {
                throw SigningError(error: signError)
            }
            return signature as Data
        }

    }

}

extension SmartCard.Store {

    fileprivate func reloadSecrets(for tokenID: String? = nil) {
        DispatchQueue.main.async {
            self.secrets.removeAll()
            self.loadSecrets()
        }
    }

    fileprivate func loadSecrets() {
        guard let id = id else { return }
        let attributes = [
            kSecClass: kSecClassKey,
            kSecAttrTokenID: id,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ] as CFDictionary
        var untyped: CFTypeRef?
        SecItemCopyMatching(attributes, &untyped)
        guard let typed = untyped as? [[CFString: Any]] else { return }
        let wrapped: [SmartCard.Secret] = typed.map {
            let name = $0[kSecAttrLabel] as? String ?? "Unnamed"
            let id = $0[kSecAttrApplicationLabel] as! Data
            let publicKeyRef = $0[kSecValueRef] as! SecKey
            let publicKeySecRef = SecKeyCopyPublicKey(publicKeyRef)!
            let publicKeyAttributes = SecKeyCopyAttributes(publicKeySecRef) as! [CFString: Any]
            let publicKey = publicKeyAttributes[kSecValueData] as! Data
            return SmartCard.Secret(id: id, name: name, publicKey: publicKey)
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
