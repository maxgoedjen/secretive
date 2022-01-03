import Foundation
import XCTest
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit

class OpenSSHWriterTests: XCTestCase {

    let writer = OpenSSHKeyWriter()

    func testECDSA256MD5Fingerprint() {
        XCTAssertEqual(writer.openSSHMD5Fingerprint(secret:  Constants.ecdsa256Secret), "dc:60:4d:ff:c2:d9:18:8b:2f:24:40:b5:7f:43:47:e5")
    }

    func testECDSA256SHA256Fingerprint() {
        XCTAssertEqual(writer.openSSHSHA256Fingerprint(secret:  Constants.ecdsa256Secret), "SHA256:/VQFeGyM8qKA8rB6WGMuZZxZLJln2UgXLk3F0uTF650")
    }

    func testECDSA256PublicKey() {
        XCTAssertEqual(writer.openSSHString(secret:  Constants.ecdsa256Secret),
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo=")
    }

    func testECDSA256Hash() {
    XCTAssertEqual(writer.data(secret: Constants.ecdsa256Secret), Data(base64Encoded: "AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo="))
    }

    func testECDSA384MD5Fingerprint() {
        XCTAssertEqual(writer.openSSHMD5Fingerprint(secret:  Constants.ecdsa384Secret), "66:e0:66:d7:41:ed:19:8e:e2:20:df:ce:ac:7e:2b:6e")
    }

    func testECDSA384SHA256Fingerprint() {
        XCTAssertEqual(writer.openSSHSHA256Fingerprint(secret:  Constants.ecdsa384Secret), "SHA256:GJUEymQNL9ymaMRRJCMGY4rWIJHu/Lm8Yhao/PAiz1I")
    }

    func testECDSA384PublicKey() {
        XCTAssertEqual(writer.openSSHString(secret:  Constants.ecdsa384Secret),
                       "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ==")
    }

    func testECDSA384Hash() {
        XCTAssertEqual(writer.data(secret: Constants.ecdsa384Secret), Data(base64Encoded: "AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ=="))
    }

}

extension OpenSSHWriterTests {

    enum Constants {
        static let ecdsa256Secret =  SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 256)", algorithm: .ellipticCurve, keySize: 256, publicKey: Data(base64Encoded: "BOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo=")!)
        static let ecdsa384Secret =  SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 384)", algorithm: .ellipticCurve, keySize: 384, publicKey: Data(base64Encoded: "BG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ==")!)

    }

}
