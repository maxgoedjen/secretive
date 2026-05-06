import Foundation
import Observation
import Security
import os
import SecretKit
import SSHProtocolKit

@Observable @MainActor public final class CertificateStore: Sendable {

    public private(set) var certificates: [OpenSSHCertificate] = []

    /// Initializes a Store.
    public init() {
        loadCertificates()
        Task {
            for await note in DistributedNotificationCenter.default().notifications(named: .certificateStoreUpdated) {
                guard Constants.notificationToken != (note.object as? String) else {
                    // Don't reload if we're the ones triggering this by reloading.
                    continue
                }
                loadCertificates()
            }
        }
    }

    public func reloadCertificates() {
        let before = certificates
        certificates.removeAll()
        loadCertificates()
        if certificates != before {
            NotificationCenter.default.post(name: .certificateStoreReloaded, object: self)
            DistributedNotificationCenter.default().postNotificationName(.certificateStoreUpdated, object: Constants.notificationToken, deliverImmediately: true)
        }
    }

    public func save(certificate: OpenSSHCertificate, originalData: Data) throws {
        let attributes = try JSONEncoder().encode(certificate)
        let keychainAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: Constants.keyTag,
            kSecAttrAccount: certificate.id,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: originalData,
            kSecAttrGeneric: attributes
        ])
        let status = SecItemAdd(keychainAttributes, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            throw KeychainError(statusCode: status)
        }
        reloadCertificates()
    }

    public func delete(certificate: OpenSSHCertificate) throws {
        let deleteAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: Constants.keyTag,
            kSecUseDataProtectionKeychain: true,
            kSecAttrAccount: certificate.id,
        ])
        let status = SecItemDelete(deleteAttributes)
        if status != errSecSuccess {
            throw KeychainError(statusCode: status)
        }
        reloadCertificates()
    }

    public func update(certificate: OpenSSHCertificate) throws {
        let updateQuery = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrAccount: certificate.id,
        ])

        let cert = try JSONEncoder().encode(certificate)
        let updatedAttributes = KeychainDictionary([
            kSecAttrGeneric: cert,
        ])

        let status = SecItemUpdate(updateQuery, updatedAttributes)
        if status != errSecSuccess {
            throw KeychainError(statusCode: status)
        }
        reloadCertificates()
    }

    public func certificates(for secret: any Secret) -> [OpenSSHCertificate] {
        certificates.filter { $0.publicKey == secret.publicKey }
    }


}

extension CertificateStore {

    /// Loads all certificates from the store.
    private func loadCertificates() {
        let queryAttributes = KeychainDictionary([
            kSecClass: Constants.keyClass,
            kSecAttrService: Constants.keyTag,
            kSecUseDataProtectionKeychain: true,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true
            ])
        var untyped: CFTypeRef?
        unsafe SecItemCopyMatching(queryAttributes, &untyped)
        guard let typed = untyped as? [[CFString: Any]] else { return }
        let decoder = JSONDecoder()
        let wrapped: [OpenSSHCertificate] = typed.compactMap {
            do {
                guard let attributesData = $0[kSecAttrGeneric] as? Data else {
                    throw MissingAttributesError()
                }
                return try decoder.decode(OpenSSHCertificate.self, from: attributesData)
            } catch {
                return nil
            }
        }
            .filter {
                if let validityRange = $0.validityRange {
                    validityRange.contains(Date())
                } else {
                    true
                }
            }
        certificates.append(contentsOf: wrapped)
    }

    
}

extension CertificateStore {

    enum Constants {
        static let keyClass = kSecClassGenericPassword as String
        static let keyTag = Data("com.maxgoedjen.certificatestore.opensshcertificate".utf8)
        static let notificationToken = UUID().uuidString
    }
    
    struct UnsupportedAlgorithmError: Error {}
    struct MissingAttributesError: Error {}

}

extension NSNotification.Name {

    // Distributed notification that keys were modified out of process (ie, that the management tool added/removed certificates)
    public static let certificateStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.certificateStore.updated")
    // Internal notification that certificates were reloaded from the backing store.
    public static let certificateStoreReloaded = NSNotification.Name("com.maxgoedjen.Secretive.certificateStore.reloaded")

}
