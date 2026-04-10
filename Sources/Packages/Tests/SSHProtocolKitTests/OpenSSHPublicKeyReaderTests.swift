import Foundation
import Testing
@testable import SecretKit
import SSHProtocolKit

@Suite struct OpenSSHPublicKeyReaderTests {

    let reader = OpenSSHPublicKeyReader()
    let writer = OpenSSHPublicKeyWriter()

    @Test func readPublicKeyLinePreservesFullCommentAndFingerprint() throws {
        let line = [
            writer.openSSHIdentifier(for: Constants.ecdsa256Secret.keyType),
            writer.data(secret: Constants.ecdsa256Secret).base64EncodedString(),
            "deploy key for staging west"
        ].joined(separator: " ")

        let parsed = try reader.readPublicKeyLine(line)

        #expect(parsed.type == writer.openSSHIdentifier(for: Constants.ecdsa256Secret.keyType))
        #expect(parsed.comment == "deploy key for staging west")
        #expect(parsed.keyBlob == writer.data(secret: Constants.ecdsa256Secret))
        #expect(parsed.fingerprint == writer.openSSHSHA256Fingerprint(secret: Constants.ecdsa256Secret))
    }

    @Test func readPublicKeyLineRejectsCertificateLines() throws {
        let line = [
            Constants.ecdsa256CertificateType,
            certificateBlob(for: Constants.ecdsa256Secret).base64EncodedString(),
            "deploy cert"
        ].joined(separator: " ")

        do {
            _ = try reader.readPublicKeyLine(line)
            Issue.record("Expected certificate line to be rejected as a bare public key")
        } catch let error {
            #expect(error == .certificateType)
        }
    }

}

extension OpenSSHPublicKeyReaderTests {

    private func certificateBlob(for secret: TestSecret) -> Data {
        let keyBlob = writer.data(secret: secret)
        let reader = OpenSSHReader(data: keyBlob)

        _ = try! reader.readNextChunkAsString()
        let curveIdentifier = try! reader.readNextChunk()
        let publicKey = try! reader.readNextChunk()

        var certificateBlob = Data()
        certificateBlob.append(Constants.ecdsa256CertificateType.lengthAndData)
        certificateBlob.append(Data("nonce".utf8).lengthAndData)
        certificateBlob.append(curveIdentifier.lengthAndData)
        certificateBlob.append(publicKey.lengthAndData)
        certificateBlob.append(uint64Data(1))
        certificateBlob.append(uint32Data(1))
        certificateBlob.append("key-id".lengthAndData)
        certificateBlob.append(Data().lengthAndData)
        certificateBlob.append(uint64Data(0))
        certificateBlob.append(uint64Data(.max))
        certificateBlob.append(Data().lengthAndData)
        certificateBlob.append(Data().lengthAndData)
        certificateBlob.append(Data().lengthAndData)
        certificateBlob.append(keyBlob.lengthAndData)
        certificateBlob.append(Data("signature".utf8).lengthAndData)
        return certificateBlob
    }

    private func uint32Data(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ])
    }

    private func uint64Data(_ value: UInt64) -> Data {
        Data([
            UInt8((value >> 56) & 0xff),
            UInt8((value >> 48) & 0xff),
            UInt8((value >> 40) & 0xff),
            UInt8((value >> 32) & 0xff),
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ])
    }

    enum Constants {
        static let ecdsa256CertificateType = "ecdsa-sha2-nistp256-cert-v01@openssh.com"
        static let ecdsa256Secret = TestSecret(id: Data(), name: "Test Key (ECDSA 256)", publicKey: Data(base64Encoded: "BOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo=")!, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 256), authentication: .notRequired, publicKeyAttribution: "test@example.com"))
    }

}
