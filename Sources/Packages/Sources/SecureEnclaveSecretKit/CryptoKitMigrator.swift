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
        
        /// Keys prior to 3.0 were created and stored directly using the keychain as kSecClassKey items. CryptoKit operates a little differently, in that it creates a key on your behalf which you can persist using an opaque data blob to a generic keychain item. Keychain created keys _also_ use this blob under the hood, but it's stored in the "toid" attribute. This migrates the old keys from kSecClassKey to generic items, copying the "toid" to be the main stored data. If the key is migrated successfully, the old key's identifier is renamed to indicate it's been migrated.
        /// - Note: Migration is non-destructive – users can still see and use their keys in older versions of Secretive.
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
            unsafe SecItemCopyMatching(privateAttributes, &privateUntyped)
            guard let privateTyped = privateUntyped as? [[CFString: Any]] else { return }
            let migratedPublicKeys = Set(store.secrets.map(\.publicKey))
            var migratedAny = false
            for key in privateTyped {
                let name = key[kSecAttrLabel] as? String ?? String(localized: .unnamedSecret)
                let id = key[kSecAttrApplicationLabel] as! Data
                guard !id.contains(Constants.migrationMagicNumber) else {
                    logger.log("Skipping \(name), already migrated.")
                    continue
                }
                let ref = key[kSecValueRef] as! SecKey
                let attributes = SecKeyCopyAttributes(ref) as! [CFString: Any]
                let tokenObjectID = unsafe attributes[Constants.tokenObjectID] as! Data
                let accessControl = attributes[kSecAttrAccessControl] as! SecAccessControl
                // Best guess.
                let auth: AuthenticationRequirement = String(describing: accessControl)
                    .contains("DeviceOwnerAuthentication") ? .presenceRequired : .unknown
                do {
                    let parsed = try CryptoKit.SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: tokenObjectID)
                    let secret = Secret(id: UUID().uuidString, name: name, publicKey: parsed.publicKey.x963Representation, attributes: Attributes(keyType: .init(algorithm: .ecdsa, size: 256), authentication: auth))
                    guard !migratedPublicKeys.contains(parsed.publicKey.x963Representation) else {
                        logger.log("Skipping \(name), public key already present. Marking as migrated.")
                        try markMigrated(secret: secret, oldID: id)
                        continue
                    }
                    logger.log("Migrating \(name).")
                    try store.saveKey(tokenObjectID, name: name, attributes: secret.attributes)
                    logger.log("Migrated \(name).")
                    try markMigrated(secret: secret, oldID: id)
                    migratedAny = true
                } catch {
                    logger.error("Failed to migrate \(name): \(error).")
                }
            }
            if migratedAny {
                store.reloadSecrets()
            }
        }



        public func markMigrated(secret: Secret, oldID: Data) throws {
            let updateQuery = KeychainDictionary([
                kSecClass: kSecClassKey,
                kSecAttrApplicationLabel: secret.id
            ])

            let newID = oldID + Constants.migrationMagicNumber
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
        // https://github.com/apple-opensource/Security/blob/5e9101b3bd1fb096bae4f40e79d50426ba1db8e9/OSX/sec/Security/SecItemConstants.c#L111
        public static nonisolated(unsafe) let tokenObjectID = "toid" as CFString
    }

}
