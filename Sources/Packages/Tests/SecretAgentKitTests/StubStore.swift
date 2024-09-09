import Foundation
import SecretKit
import CryptoKit

struct Stub {}

extension Stub {

    public final class Store: SecretStore {

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

            let attributes : NSDictionary = [
                kSecAttrLabel: name,
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits: size,
                kSecPrivateKeyAttrs: [
                    kSecAttrIsPermanent: true,
                    kSecAttrAccessControl: access
                ]
                ]

            let privateKey = SecKeyCreateRandomKey(attributes, nil)!
            let publicKey = SecKeyCopyPublicKey(privateKey)!
            let publicAttributes = SecKeyCopyAttributes(publicKey) as! [CFString: Any]
            let privateAttributes = SecKeyCopyAttributes(privateKey) as! [CFString: Any]
            let publicData = (publicAttributes[kSecValueData] as! Data)
            let privateData = (privateAttributes[kSecValueData] as! Data)
            let secret = Secret(keySize: size, publicKey: publicData, privateKey: privateData)
            print(secret)
            print("Public Key OpenSSH: \(OpenSSHKeyWriter().openSSHString(secret: secret))")
        }

        public func sign(data: Data, with secret: Secret, for provenance: SigningRequestProvenance) throws -> Data {
            guard !shouldThrow else {
                throw NSError(domain: "test", code: 0, userInfo: nil)
            }
            let privateKey = SecKeyCreateWithData(secret.privateKey as CFData, [
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits: secret.keySize,
                kSecAttrKeyClass: kSecAttrKeyClassPrivate
                ] as CFDictionary
                , nil)!
            return SecKeyCreateSignature(privateKey, signatureAlgorithm(for: secret), data as CFData, nil)! as Data
        }

        public func verify(signature: Data, for data: Data, with secret: Stub.Secret) throws -> Bool {
            let attributes: NSDictionary = [
                kSecAttrKeyType: secret.algorithm.secAttrKeyType,
                kSecAttrKeySizeInBits: secret.keySize,
                kSecAttrKeyClass: kSecAttrKeyClassPublic
            ]
            var verifyError: Unmanaged<CFError>?
            let untyped: CFTypeRef? = SecKeyCreateWithData(secret.publicKey as CFData, attributes, &verifyError)
            guard let untypedSafe = untyped else {
                throw NSError(domain: "test", code: 0, userInfo: nil)
            }
            let key = untypedSafe as! SecKey
            let verified = SecKeyVerifySignature(key, signatureAlgorithm(for: secret), data as CFData, signature as CFData, &verifyError)
            if let verifyError {
                if verifyError.takeUnretainedValue() ~= .verifyError {
                    return false
                } else {
                    throw NSError(domain: "test", code: 0, userInfo: nil)
                }
            }
            return verified
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

        let id = UUID().uuidString.data(using: .utf8)!
        let name = UUID().uuidString
        let algorithm = Algorithm.ellipticCurve

        let keySize: Int
        let publicKey: Data
        let requiresAuthentication = false
        let privateKey: Data

        init(keySize: Int, publicKey: Data, privateKey: Data) {
            self.keySize = keySize
            self.publicKey = publicKey
            self.privateKey = privateKey
        }

        var debugDescription: String {
            """
            Key Size \(keySize)
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
