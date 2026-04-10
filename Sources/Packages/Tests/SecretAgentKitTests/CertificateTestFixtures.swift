import Foundation
import SecretKit
import SSHProtocolKit

enum CertificateTestFixtures {

    static let writer = OpenSSHPublicKeyWriter()
    static let ecdsa256CertificateType = "ecdsa-sha2-nistp256-cert-v01@openssh.com"
    static let ecdsa256Secret = Stub.Secret(
        keySize: 256,
        publicKey: Data(base64Encoded: "BKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy08=")!,
        privateKey: Data(base64Encoded: "BKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy09nw780wy/TSfUmzj15iJkV234AaCLNl+H8qFL6qK8VIg==")!
    )
    static let ecdsa384Secret = Stub.Secret(
        keySize: 384,
        publicKey: Data(base64Encoded: "BLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDA==")!,
        privateKey: Data(base64Encoded: "BLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDHNapAOzrt9E+9QC4/KYoXS7Uw4pmdAz53uIj02tttiq3c0ZyIQ7XoscWWRqRrz8Kw==")!
    )

    static func certificateBlob(
        for secret: Stub.Secret,
        certificateType: String = ecdsa256CertificateType,
        validAfter: UInt64 = 0,
        validBefore: UInt64 = .max
    ) -> Data {
        let keyBlob = writer.data(secret: secret)
        let reader = OpenSSHReader(data: keyBlob)
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

    static func certificateLine(
        for secret: Stub.Secret,
        comment: String,
        validAfter: UInt64 = 0,
        validBefore: UInt64 = .max
    ) -> String {
        [
            ecdsa256CertificateType,
            certificateBlob(
                for: secret,
                validAfter: validAfter,
                validBefore: validBefore
            ).base64EncodedString(),
            comment
        ].joined(separator: " ")
    }

    static func signRequest(for keyBlob: Data, dataToSign: Data) -> Data {
        let body = keyBlob.lengthAndData +
        dataToSign.lengthAndData +
        uint32Data(0)
        return uint32Data(UInt32(body.count + 1)) +
        Data([SSHAgent.Request.signRequest(.empty).protocolID]) +
        body
    }

    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func write(_ contents: String, to fileURL: URL) throws {
        try Data(contents.utf8).write(to: fileURL, options: .atomic)
    }

    static func uint32Data(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ])
    }

    static func uint64Data(_ value: UInt64) -> Data {
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

}
