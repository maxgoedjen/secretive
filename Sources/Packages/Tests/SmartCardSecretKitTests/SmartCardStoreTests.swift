import Foundation
import Testing
import CryptoKit
import SSHProtocolKit
@testable import SecretKit
@testable import SmartCardSecretKit

@Suite struct SmartCardStoreTests {

    let writer = OpenSSHSignatureWriter()

    // MARK: Raw Signatures

    @Test func ecdsa256RawSignature() throws {
        let raw = try SmartCard.Store.rawSignature(signature: Constants.ecdsa256Signature, keyType: Constants.ecdsa256Secret.keyType)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: raw)
        #expect(try P256.Signing.PublicKey(x963Representation: Constants.ecdsa256Secret.publicKey)
            .isValidSignature(signature, for: Constants.data))
    }

    @Test func ecdsa384RawSignature() throws {
        let raw = try SmartCard.Store.rawSignature(signature: Constants.ecdsa384Signature, keyType: Constants.ecdsa384Secret.keyType)
        let signature = try P384.Signing.ECDSASignature(rawRepresentation: raw)
        #expect(try P384.Signing.PublicKey(x963Representation: Constants.ecdsa384Secret.publicKey)
            .isValidSignature(signature, for: Constants.data))
    }

    @Test func rsaRawSignature() throws {
        let signature = Data(repeating: 0x01, count: 256)
        let raw = try SmartCard.Store.rawSignature(signature: signature, keyType: KeyType(algorithm: .rsa, size: 2048))
        #expect(raw == signature)
    }

    // MARK: OpenSSH Signatures

    @Test func ecdsa256OpenSSHSignature() throws {
        let raw = try SmartCard.Store.rawSignature(signature: Constants.ecdsa256Signature, keyType: Constants.ecdsa256Secret.keyType)
        let reader = OpenSSHReader(data: writer.data(secret: Constants.ecdsa256Secret, signature: raw))
        let inner = try reader.readNextChunkAsSubReader()
        #expect(try inner.readNextChunkAsString() == "ecdsa-sha2-nistp256")
        let rsData = try inner.readNextChunkAsSubReader()
        var r = try rsData.readNextChunk()
        var s = try rsData.readNextChunk()
        // This is fine IRL, but it freaks out CryptoKit
        if r[0] == 0 {
            r.removeFirst()
        }
        if s[0] == 0 {
            s.removeFirst()
        }
        var rs = r
        rs.append(s)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: rs)
        #expect(try P256.Signing.PublicKey(x963Representation: Constants.ecdsa256Secret.publicKey)
            .isValidSignature(signature, for: Constants.data))
    }

    @Test func ecdsa384OpenSSHSignature() throws {
        let raw = try SmartCard.Store.rawSignature(signature: Constants.ecdsa384Signature, keyType: Constants.ecdsa384Secret.keyType)
        let reader = OpenSSHReader(data: writer.data(secret: Constants.ecdsa384Secret, signature: raw))
        let inner = try reader.readNextChunkAsSubReader()
        #expect(try inner.readNextChunkAsString() == "ecdsa-sha2-nistp384")
        let rsData = try inner.readNextChunkAsSubReader()
        var r = try rsData.readNextChunk()
        var s = try rsData.readNextChunk()
        // This is fine IRL, but it freaks out CryptoKit
        if r[0] == 0 {
            r.removeFirst()
        }
        if s[0] == 0 {
            s.removeFirst()
        }
        var rs = r
        rs.append(s)
        let signature = try P384.Signing.ECDSASignature(rawRepresentation: rs)
        #expect(try P384.Signing.PublicKey(x963Representation: Constants.ecdsa384Secret.publicKey)
            .isValidSignature(signature, for: Constants.data))
    }

}

extension SmartCardStoreTests {

    enum Constants {
        static let data = Data("Test".utf8)
        static let ecdsa256Secret = SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 256)", publicKey: Data(base64Encoded: "BHoOpOruhZu0Ju5jqm/o10RsqtntTTOGICZ6YT+jEZeVEzI89yWO4mY2qapgnLGhXD0S7NXxrVkAmSH9ozKZRBk=")!, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 256), authentication: .notRequired))
        static let ecdsa384Secret = SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 384)", publicKey: Data(base64Encoded: "BLgsxw//vqRYdVpAOpRWeo3/3MFxxTbzfvhxZstii1KRV8sphnaKkgo7XzJ0z09GI2Ya9E557+niGboYAR8xQ8cn7hwbeITNST/nXyO6vjvu3GLTVUENnoPg8m5N6+Cgzg==")!, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 384), authentication: .notRequired))
        static let ecdsa256Signature = Data(base64Encoded: "MEYCIQCvOfQ5XT6bpJst7tnN3BLdfNnrvealAqYTissnQBhVOAIhAONDE07bFZ3f1naWc0YYEKYWQ1UWH4L5UOnuEGRNioYg")!
        static let ecdsa384Signature = Data(base64Encoded: "MGYCMQDQMkmu1tH5/hH9zVjAFELVlQHSX1xv6CYnWszBh4d0X94B1skdkzfM8vZJ/XM5NCwCMQDXv68YN3Nr/d4ATsg3HUkIlFT4mPpvvD7erm/Vgaw7XA1YGo4Ge7i83aYjej1HFyI=")!
    }

}
