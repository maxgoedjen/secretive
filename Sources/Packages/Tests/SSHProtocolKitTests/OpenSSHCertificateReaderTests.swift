import Foundation
import Testing
@testable import SecretKit
import SSHProtocolKit

@Suite struct OpenSSHCertificateReaderTests {

    let writer = OpenSSHPublicKeyWriter()
    let certificateReader = OpenSSHCertificateReader()

    @Test func readPublicKeyLinePreservesFullCommentAndFingerprint() throws {
        let certificateBlob = certificateBlob(
            for: Constants.ecdsa256Secret,
            validAfter: 42,
            validBefore: 4_102_444_800
        )
        let line = [
            Constants.ecdsa256CertificateType,
            certificateBlob.base64EncodedString(),
            "deploy cert for production west"
        ].joined(separator: " ")

        let parsed = try certificateReader.readPublicKeyLine(line)

        #expect(parsed.type == Constants.ecdsa256CertificateType)
        #expect(parsed.comment == "deploy cert for production west")
        #expect(parsed.subjectKeyBlob == writer.data(secret: Constants.ecdsa256Secret))
        #expect(parsed.subjectKeyFingerprint == writer.openSSHSHA256Fingerprint(secret: Constants.ecdsa256Secret))
        #expect(parsed.validAfter == 42)
        #expect(parsed.validBefore == 4_102_444_800)
    }

    @Test func readCertificateBlobExposesExpirationState() throws {
        let expiredCertificate = try certificateReader.readCertificateBlob(
            certificateBlob(
                for: Constants.ecdsa256Secret,
                validBefore: 1
            )
        )
        let activeCertificate = try certificateReader.readCertificateBlob(
            certificateBlob(
                for: Constants.ecdsa256Secret,
                validBefore: .max
            )
        )

        #expect(expiredCertificate.isExpired(at: Date(timeIntervalSince1970: 2)))
        #expect(!activeCertificate.isExpired(at: Date(timeIntervalSince1970: 2)))
    }

    @Test func readCertificateBlobRejectsBarePublicKey() throws {
        do {
            _ = try certificateReader.readCertificateBlob(writer.data(secret: Constants.ecdsa256Secret))
            Issue.record("Expected bare public key to be rejected as a certificate")
        } catch let error {
            #expect(error == .unsupportedType)
        }
    }

    @Test func readCertificateBlobRejectsTruncatedCertificate() throws {
        let truncatedBlob = Constants.ecdsa256CertificateType.lengthAndData + Data("nonce".utf8).lengthAndData

        do {
            _ = try certificateReader.readCertificateBlob(truncatedBlob)
            Issue.record("Expected truncated certificate blob to fail parsing")
        } catch let error {
            #expect(error == .parsingFailed)
        }
    }

}

extension OpenSSHCertificateReaderTests {

    private func certificateBlob(
        for secret: TestSecret,
        type: String? = nil,
        validAfter: UInt64 = 0,
        validBefore: UInt64 = .max
    ) -> Data {
        let keyBlob = writer.data(secret: secret)
        let reader = OpenSSHReader(data: keyBlob)
        let certificateType = type ?? Constants.ecdsa256CertificateType

        _ = try! reader.readNextChunkAsString()
        let curveIdentifier = try! reader.readNextChunk()
        let publicKey = try! reader.readNextChunk()

        var certificateBlob = Data()
        certificateBlob.append(certificateType.lengthAndData)
        certificateBlob.append(Data("nonce".utf8).lengthAndData)
        certificateBlob.append(curveIdentifier.lengthAndData)
        certificateBlob.append(publicKey.lengthAndData)
        certificateBlob.append(uint64Data(1))
        certificateBlob.append(uint32Data(1))
        certificateBlob.append("key-id".lengthAndData)
        certificateBlob.append(Data().lengthAndData)
        certificateBlob.append(uint64Data(validAfter))
        certificateBlob.append(uint64Data(validBefore))
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
