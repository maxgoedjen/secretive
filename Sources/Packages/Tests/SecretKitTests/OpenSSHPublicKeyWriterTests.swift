import Foundation
import Testing
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit

@Suite struct OpenSSHPublicKeyWriterTests {

    let writer = OpenSSHPublicKeyWriter()

    @Test func ecdsa256MD5Fingerprint() {
        #expect(writer.openSSHMD5Fingerprint(secret:  Constants.ecdsa256Secret) == "dc:60:4d:ff:c2:d9:18:8b:2f:24:40:b5:7f:43:47:e5")
    }

    @Test func ecdsa256SHA256Fingerprint() {
        #expect(writer.openSSHSHA256Fingerprint(secret:  Constants.ecdsa256Secret) == "SHA256:/VQFeGyM8qKA8rB6WGMuZZxZLJln2UgXLk3F0uTF650")
    }

    @Test func ecdsa256PublicKey() {
        #expect(writer.openSSHString(secret:  Constants.ecdsa256Secret) ==
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo= test@example.com")
    }

    @Test func ecdsa256Hash() {
    #expect(writer.data(secret: Constants.ecdsa256Secret) == Data(base64Encoded: "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo="))
    }

    @Test func ecdsa384MD5Fingerprint() {
        #expect(writer.openSSHMD5Fingerprint(secret:  Constants.ecdsa384Secret) == "66:e0:66:d7:41:ed:19:8e:e2:20:df:ce:ac:7e:2b:6e")
    }

    @Test func ecdsa384SHA256Fingerprint() {
        #expect(writer.openSSHSHA256Fingerprint(secret:  Constants.ecdsa384Secret) == "SHA256:GJUEymQNL9ymaMRRJCMGY4rWIJHu/Lm8Yhao/PAiz1I")
    }

    @Test func ecdsa384PublicKey() {
        #expect(writer.openSSHString(secret:  Constants.ecdsa384Secret) ==
                       "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ== test@example.com")
    }

    @Test func ecdsa384Hash() {
        #expect(writer.data(secret: Constants.ecdsa384Secret) == Data(base64Encoded: "AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ=="))
    }

}

extension OpenSSHPublicKeyWriterTests {

    enum Constants {
        static let ecdsa256Secret =  SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 256)", publicKey: Data(base64Encoded: "BOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo=")!, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 256), authentication: .notRequired, publicKeyAttribution: "test@example.com"))
        static let ecdsa384Secret = SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 384)", publicKey: Data(base64Encoded: "BG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ==")!, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 384), authentication: .notRequired, publicKeyAttribution: "test@example.com"))

    }

}
