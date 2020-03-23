import SecretKit
import CryptoKit

struct Stub {}

extension Stub {

    public class Store: SecretStore {

        public let isAvailable = true
        public let id = UUID()
        public let name = "Stub"
        public var secrets: [Secret] = []

        public init() {
            try! create(size: 256)
        }

        public func create(size: Int) throws {
            let flags: SecAccessControlCreateFlags = []
            let access =
                SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                flags,
                                                nil) as Any

            let attributes = [
                kSecAttrLabel: name,
                kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits: size,
                kSecPrivateKeyAttrs: [
                    kSecAttrIsPermanent: true,
                    kSecAttrAccessControl: access
                ]
            ] as CFDictionary

            var privateKey: SecKey! = nil
            var publicKey: SecKey! = nil
            SecKeyGeneratePair(attributes, &publicKey, &privateKey)
            let publicAttributes = SecKeyCopyAttributes(publicKey) as! [CFString: Any]
            let privateAttributes = SecKeyCopyAttributes(privateKey) as! [CFString: Any]
            let publicData = (publicAttributes[kSecValueData] as! Data)
            let privateData = (privateAttributes[kSecValueData] as! Data)
            let secret = Secret(keySize: size, publicKey: publicData, privateKey: privateData)
            print(secret)
            print("Public Key OpenSSH: \(OpenSSHKeyWriter().openSSHString(secret: secret))")
        }

        public func delete(secret: Secret) throws {
        }

        public func sign(data: Data, with secret: Secret) throws -> Data {
            return Data()
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
