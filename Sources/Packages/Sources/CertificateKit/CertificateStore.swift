import Foundation
import Observation
import Security
import os
import SecretKit

@Observable public final class CertificateStore {

    @MainActor private var certificates: [Certificate] = []

    /// Initializes a Store.
    @MainActor public init() {
        loadCertificates()
        Task {
//            for await note in DistributedNotificationCenter.default().notifications(named: .certificateStoreUpdated) {
//                guard Constants.notificationToken != (note.object as? String) else {
//                    // Don't reload if we're the ones triggering this by reloading.
//                    continue
//                }
//                loadCertificates()
//            }
        }
    }

    @MainActor public func reloadCertificates() {
        let before = certificates
        certificates.removeAll()
        loadCertificates()
        if certificates != before {
//            NotificationCenter.default.post(name: .certificateStoreReloaded, object: self)
//            DistributedNotificationCenter.default().postNotificationName(.certificateStoreUpdated, object: Constants.notificationToken, deliverImmediately: true)
        }
    }

    @MainActor public func saveCertificate(_ data: Data, for secret: any Secret) {
        let certificate = SecCertificateCreateWithData(nil, data as CFData)
        print(certificate as Any)
    }

    @MainActor public func certificates(for secret: any Secret) -> [Certificate] {
        []
    }


}

extension CertificateStore {

    /// Loads all certificates from the store.
    @MainActor private func loadCertificates() {
//        let queryAttributes = KeychainDictionary([
//            kSecClass: Constants.keyClass,
//            kSecAttrService: Constants.keyTag,
//            kSecUseDataProtectionKeychain: true,
//            kSecReturnData: true,
//            kSecMatchLimit: kSecMatchLimitAll,
//            kSecReturnAttributes: true
//            ])
//        var untyped: CFTypeRef?
//        unsafe SecItemCopyMatching(queryAttributes, &untyped)
//        guard let typed = untyped as? [[CFString: Any]] else { return }
//        let wrapped: [SecureEnclave.Certificates] = typed.compactMap {
//            do {
//                let name = $0[kSecAttrLabel] as? String ?? String(localized: "unnamed_certificate")
//                guard let attributesData = $0[kSecAttrGeneric] as? Data,
//                let id = $0[kSecAttrAccount] as? String else {
//                    throw MissingAttributesError()
//                }
//                let attributes = try JSONDecoder().decode(Attributes.self, from: attributesData)
//                let keyData = $0[kSecValueData] as! Data
//                let publicKey: Data
//                switch attributes.keyType {
//                case .ecdsa256:
//                    let key = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
//                    publicKey = key.publicKey.x963Representation
//                case .mldsa65:
//                    guard #available(macOS 26.0, *)  else { throw UnsupportedAlgorithmError() }
//                    let key = try CryptoKit.SecureEnclave.MLDSA65.PrivateKey(dataRepresentation: keyData)
//                    publicKey = key.publicKey.rawRepresentation
//                case .mldsa87:
//                    guard #available(macOS 26.0, *)  else { throw UnsupportedAlgorithmError() }
//                    let key = try CryptoKit.SecureEnclave.MLDSA87.PrivateKey(dataRepresentation: keyData)
//                    publicKey = key.publicKey.rawRepresentation
//                default:
//                    throw UnsupportedAlgorithmError()
//                }
//                return SecureEnclave.Certificates(id: id, name: name, publicKey: publicKey, attributes: attributes)
//            } catch {
//                return nil
//            }
//        }
//        certificates.append(contentsOf: wrapped)
    }

    /// Saves a public key.
    /// - Parameters:
    ///   - key: The data representation key to save.
    ///   - name: A user-facing name for the key.
    ///   - attributes: Attributes of the key.
    /// - Note: Despite the name, the "Data" of the key is _not_ actual key material. This is an opaque data representation that the SEP can manipulate.
//    @discardableResult
//    func saveKey(_ key: Data, name: String, attributes: Attributes) throws -> String {
//        let attributes = try JSONEncoder().encode(attributes)
//        let id = UUID().uuidString
//        let keychainAttributes = KeychainDictionary([
//            kSecClass: Constants.keyClass,
//            kSecAttrService: Constants.keyTag,
//            kSecUseDataProtectionKeychain: true,
//            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
//            kSecAttrAccount: id,
//            kSecValueData: key,
//            kSecAttrLabel: name,
//            kSecAttrGeneric: attributes
//        ])
//        let status = SecItemAdd(keychainAttributes, nil)
//        if status != errSecSuccess {
//            throw KeychainError(statusCode: status)
//        }
//        return id
//    }
    
}

extension CertificateStore {

    enum Constants {
        static let keyClass = kSecClassCertificate as String
        static let keyTag = Data("com.maxgoedjen.certificateive.certificate".utf8)
        static let notificationToken = UUID().uuidString
    }
    
    struct UnsupportedAlgorithmError: Error {}

}
