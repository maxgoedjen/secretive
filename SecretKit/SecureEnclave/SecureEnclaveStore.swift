import Foundation
import Security
import CryptoTokenKit

extension SecureEnclave {

    public class Store: SecretStore {

        public var isAvailable: Bool {
            // For some reason, as of build time, CryptoKit.SecureEnclave.isAvailable always returns false
            // error msg "Received error sending GET UNIQUE DEVICE command"
            // Verify it with TKTokenWatcher manually.
            return TKTokenWatcher().tokenIDs.contains("com.apple.setoken")
        }
        public let name = NSLocalizedString("Secure Enclave", comment: "Secure Enclave")
        @Published public fileprivate(set) var secrets: [Secret] = []

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

        public func sign(data: Data, with secret: SecretType) throws -> Data {
            let attributes = [
                kSecClass: kSecClassKey,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecAttrApplicationLabel: secret.id as CFData,
                kSecAttrKeyType: Constants.keyType,
                kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
                kSecAttrApplicationTag: Constants.keyTag,
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

extension SecureEnclave.Store {

    fileprivate func reloadSecrets(notify: Bool = true) {
        secrets.removeAll()
        loadSecrets()
        if notify {
            DistributedNotificationCenter.default().post(name: .secretStoreUpdated, object: nil)
        }
    }

    fileprivate func loadSecrets() {
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

    fileprivate func savePublicKey(_ publicKey: SecKey, name: String) throws {
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

}

extension SecureEnclave {

    public typealias SecurityError = Unmanaged<CFError>

}

extension SecureEnclave {

    enum Constants {
        fileprivate static let keyTag = "com.maxgoedjen.secretive.secureenclave.key".data(using: .utf8)! as CFData
        fileprivate static let keyType = kSecAttrKeyTypeECSECPrimeRandom
    }

}
