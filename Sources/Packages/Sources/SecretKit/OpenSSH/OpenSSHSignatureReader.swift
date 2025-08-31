import Foundation
import CryptoKit
import Security

/// Reads OpenSSH representations of Secrets.
public struct OpenSSHSignatureReader: Sendable {

    /// Initializes the reader.
    public init() {
    }

    public func verify(_ signatureData: Data, for signedData: Data, with publicKey: Data) throws -> Bool {
        let reader = OpenSSHReader(data: signatureData)
        let signatureType = try reader.readNextChunkAsString()
        let signatureData = try reader.readNextChunk()
        switch signatureType {
        case "ssh-rsa":
            let attributes = KeychainDictionary([
                kSecAttrKeyType: kSecAttrKeyTypeRSA,
                kSecAttrKeySizeInBits: 2048,
                kSecAttrKeyClass: kSecAttrKeyClassPublic
            ])
            var verifyError: SecurityError?
            let untyped: CFTypeRef? = SecKeyCreateWithData(publicKey as CFData, attributes, &verifyError)
            guard let untypedSafe = untyped else {
                throw KeychainError(statusCode: errSecSuccess)
            }
            let key = untypedSafe as! SecKey
            return SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA512, signedData as CFData, signatureData as CFData, nil)
        case "ecdsa-sha2-nistp256":
            return try P256.Signing.PublicKey(rawRepresentation: publicKey).isValidSignature(.init(rawRepresentation: signatureData), for: signedData)
        case "ecdsa-sha2-nistp384":
            return try P384.Signing.PublicKey(rawRepresentation: publicKey).isValidSignature(.init(rawRepresentation: signatureData), for: signedData)
        case "ecdsa-sha2-nistp521":
            return try P521.Signing.PublicKey(rawRepresentation: publicKey).isValidSignature(.init(rawRepresentation: signatureData), for: signedData)
        case "ssh-ed25519":
            return try Curve25519.Signing.PublicKey(rawRepresentation: publicKey).isValidSignature(signatureData, for: signedData)
        case "ssh-mldsa-65":
            if #available(macOS 26.0, *) {
                return try MLDSA65.PublicKey(rawRepresentation: publicKey).isValidSignature(signatureData, for: signedData)
            } else {
                throw UnsupportedSignatureType()
            }
        case "ssh-mldsa-87":
            if #available(macOS 26.0, *) {
                return try MLDSA87.PublicKey(rawRepresentation: publicKey).isValidSignature(signatureData, for: signedData)
            } else {
                throw UnsupportedSignatureType()
            }
        default:
            throw UnsupportedSignatureType()
        }
    }

    public struct UnsupportedSignatureType: Error {}

}
