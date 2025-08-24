import Foundation
import Security
import CryptoTokenKit
import CryptoKit
import SecretKit
import os

extension SecureEnclave {

    public struct CryptoKitMigrator {

        private let logger = Logger(subsystem: "com.maxgoedjen.secretive.migration", category: "CryptoKitMigrator")

        public init() {
        }

        @MainActor public func migrate(to store: Store) throws {
            let privateAttributes = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrKeyType: Constants.oldKeyType,
                kSecAttrApplicationTag: SecureEnclave.Store.Constants.keyTag,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate,
                kSecReturnRef: true,
                kSecMatchLimit: kSecMatchLimitAll,
                kSecReturnAttributes: true
            ])
            var privateUntyped: CFTypeRef?
            SecItemCopyMatching(privateAttributes, &privateUntyped)
            guard let privateTyped = privateUntyped as? [[CFString: Any]] else { return }
            let migratedPublicKeys = Set(store.secrets.map(\.publicKey))
            var migrated = false
            for key in privateTyped {
                let name = key[kSecAttrLabel] as? String ?? String(localized: .unnamedSecret)
                let id = key[kSecAttrApplicationLabel] as! Data
                guard !id.contains(Constants.migrationMagicNumber) else {
                    logger.log("Skipping \(name), already migrated.")
                    continue
                }
                let ref = key[kSecValueRef] as! SecKey
                let attributes = SecKeyCopyAttributes(ref) as! [CFString: Any]
                let tokenObjectID = attributes[Constants.tokenObjectID] as! Data
                let accessControl = attributes[kSecAttrAccessControl] as! SecAccessControl
                // Best guess.
                let auth: AuthenticationRequirement = String(describing: accessControl)
                    .contains("DeviceOwnerAuthentication") ? .presenceRequired : .unknown
                let parsed = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: tokenObjectID)
                let secret = Secret(id: id, name: name, publicKey: parsed.publicKey.x963Representation, attributes: Attributes(keyType: .init(algorithm: .ecdsa, size: 256), authentication: auth))
                guard !migratedPublicKeys.contains(parsed.publicKey.x963Representation) else {
                    logger.log("Skipping \(name), public key already present. Marking as migrated.")
                    try markMigrated(secret: secret)
                    continue
                }
                logger.log("Migrating \(name).")
                try store.saveKey(tokenObjectID, name: name, attributes: secret.attributes)
                logger.log("Migrated \(name).")
                try markMigrated(secret: secret)
                migrated = true
            }
            if migrated {
                store.reloadSecrets()
            }
        }



        public func markMigrated(secret: Secret) throws {
            let updateQuery = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id as CFData
            ])

            let newID = secret.id + Constants.migrationMagicNumber
            let updatedAttributes = KeychainDictionary([
                kSecAttrApplicationLabel: newID as CFData
            ])

            let status = SecItemUpdate(updateQuery, updatedAttributes)
            if status != errSecSuccess {
                throw KeychainError(statusCode: status)
            }
        }


    }

}

extension SecureEnclave.CryptoKitMigrator {

    enum Constants {
        public static let oldKeyType = kSecAttrKeyTypeECSECPrimeRandom as String
        public static let migrationMagicNumber = Data("_cryptokit_1".utf8)
        public static nonisolated(unsafe) let tokenObjectID = "toid" as CFString
    }

}
