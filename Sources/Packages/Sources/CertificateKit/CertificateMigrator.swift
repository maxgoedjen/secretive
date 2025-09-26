import Foundation
import Security
import CryptoTokenKit
import CryptoKit
import os
import SSHProtocolKit

public struct CertificateKitMigrator {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.migration", category: "CertificateKitMigrator")
    let directory: URL

    /// Initializes a PublicKeyFileStoreController.
    public init(homeDirectory: URL) {
        directory = homeDirectory.appending(component: "PublicKeys")
    }

    @MainActor public func migrate() throws {
        let fileCerts = try FileManager.default
            .contentsOfDirectory(atPath: directory.path())
            .filter { $0.hasSuffix("-cert.pub") }
        Task {
            for path in fileCerts {
                let url = directory.appending(component: path)
                let data = try! Data(contentsOf: url)
//                let parser = try! await XPCCertificateParser()
                let parser = OpenSSHCertificateParser()
                let cert = try! await parser.parse(data: data)
                print(cert)
//                let secret = storeList.allSecrets.first { secret in
//                    secret.name == cert.name
//                }
//                guard let secret = secret ?? storeList.allSecrets.first else { return }
//                print(cert.data.formatted(.hex()))
//                certificateStore.saveCertificate(cert.data, for: secret)
                print(cert)
            }

        }

//        let privateAttributes = KeychainDictionary([
//            kSecClass: kSecClassKey,
//            kSecAttrKeyType: Constants.oldKeyType,
//            kSecAttrApplicationTag: SecureEnclave.Store.Constants.keyTag,
//            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
//            kSecReturnRef: true,
//            kSecMatchLimit: kSecMatchLimitAll,
//            kSecReturnAttributes: true
//        ])
//        var privateUntyped: CFTypeRef?
//        unsafe SecItemCopyMatching(privateAttributes, &privateUntyped)
//        guard let privateTyped = privateUntyped as? [[CFString: Any]] else { return }
//        let migratedPublicKeys = Set(store.secrets.map(\.publicKey))
//        var migratedAny = false
//        for key in privateTyped {
//            let name = key[kSecAttrLabel] as? String ?? String(localized: .unnamedSecret)
//            let id = key[kSecAttrApplicationLabel] as! Data
//            guard !id.contains(Constants.migrationMagicNumber) else {
//                logger.log("Skipping \(name), already migrated.")
//                continue
//            }
//            let ref = key[kSecValueRef] as! SecKey
//            let attributes = SecKeyCopyAttributes(ref) as! [CFString: Any]
//            let tokenObjectID = unsafe attributes[Constants.tokenObjectID] as! Data
//            let accessControl = attributes[kSecAttrAccessControl] as! SecAccessControl
//            // Best guess.
//            let auth: AuthenticationRequirement = String(describing: accessControl)
//                .contains("DeviceOwnerAuthentication") ? .presenceRequired : .unknown
//            do {
//                let parsed = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: tokenObjectID)
//                let secret = Secret(id: UUID().uuidString, name: name, publicKey: parsed.publicKey.x963Representation, attributes: Attributes(keyType: .init(algorithm: .ecdsa, size: 256), authentication: auth))
//                guard !migratedPublicKeys.contains(parsed.publicKey.x963Representation) else {
//                    logger.log("Skipping \(name), public key already present. Marking as migrated.")
//                    markMigrated(secret: secret, oldID: id)
//                    continue
//                }
//                logger.log("Migrating \(name).")
//                try store.saveKey(tokenObjectID, name: name, attributes: secret.attributes)
//                logger.log("Migrated \(name).")
//                markMigrated(secret: secret, oldID: id)
//                migratedAny = true
//            } catch {
//                logger.error("Failed to migrate \(name): \(error.localizedDescription).")
//            }
//        }
//        if migratedAny {
//            store.reloadSecrets()
//        }
    }

}
