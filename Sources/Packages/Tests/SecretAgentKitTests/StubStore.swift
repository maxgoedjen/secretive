import Foundation
import SecretKit
import CryptoKit

struct Stub {}

extension Stub {

    public final class Store: SecretStore, @unchecked Sendable {

        public let isAvailable = true
        public let id = UUID()
        public let name = "Stub"
        public var secrets: [Secret] = []
        public var shouldThrow = false

        public init() {
//            try! create(size: 256)
//            try! create(size: 384)
        }

        public func create(size: Int) throws {
            let flags: SecAccessControlCreateFlags = []
            let access =
                SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                flags,
                                                nil) as Any

            let attributes = KeychainDictionary([
                kSecAttrLabel: name,
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits: size,
                kSecPrivateKeyAttrs: [
                    kSecAttrIsPermanent: true,
                    kSecAttrAccessControl: access
                ]
                ])

            let privateKey = SecKeyCreateRandomKey(attributes, nil)!
            let publicKey = SecKeyCopyPublicKey(privateKey)!
            let publicAttributes = SecKeyCopyAttributes(publicKey) as! [CFString: Any]
            let privateAttributes = SecKeyCopyAttributes(privateKey) as! [CFString: Any]
            let publicData = (publicAttributes[kSecValueData] as! Data)
            let privateData = (privateAttributes[kSecValueData] as! Data)
            let secret = Secret(keySize: size, publicKey: publicData, privateKey: privateData)
            print(secret)
            print("Public Key OpenSSH: \(OpenSSHPublicKeyWriter().openSSHString(secret: secret))")
        }

        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) throws -> Data {
            guard !shouldThrow else {
                throw NSError(domain: "test", code: 0, userInfo: nil)
            }
            let privateKey = try CryptoKit.P256.Signing.PrivateKey(x963Representation: secret.privateKey)
            return try privateKey.signature(for: data).rawRepresentation
        }

        public func existingPersistedAuthenticationContext(secret: Stub.Secret) -> PersistedAuthenticationContext? {
            nil
        }

        public func persistAuthentication(secret: Stub.Secret, forDuration duration: TimeInterval) throws {
        }

        public func reloadSecrets() {
        }

    }

}

extension Stub {

    struct Secret: SecretKit.Secret, CustomDebugStringConvertible {

        let id = Data(UUID().uuidString.utf8)
        let name = UUID().uuidString
        let attributes: Attributes
        let publicKey: Data
        let requiresAuthentication = false
        let privateKey: Data

        init(keySize: Int, publicKey: Data, privateKey: Data) {
            self.attributes = Attributes(keyType: .init(algorithm: .ecdsa, size: keySize), authentication: .notRequired)
            self.publicKey = publicKey
            self.privateKey = privateKey
        }

        var debugDescription: String {
            """
            Key Size \(attributes.keyType.size)
            Private: \(privateKey.base64EncodedString())
            Public: \(publicKey.base64EncodedString())
            """
        }

    }

}


extension Stub.Store {

    struct StubError: Error {
    }

}
