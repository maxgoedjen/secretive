import Foundation
import CryptoKit

/// Generates OpenSSH representations of Secrets.
public struct OpenSSHSignatureWriter: Sendable {

    /// Initializes the writer.
    public init() {
    }

    /// Generates an OpenSSH data payload identifying the secret.
    /// - Returns: OpenSSH data payload identifying the secret.
    public func data<SecretType: Secret>(secret: SecretType, signature: Data) -> Data {
        switch secret.keyType.algorithm {
        case .ecdsa:
            // https://datatracker.ietf.org/doc/html/rfc5656#section-3.1
            ecdsaSignature(signature, keyType: secret.keyType)
        case .rsa:
            // https://datatracker.ietf.org/doc/html/rfc4253#section-6.6
            rsaSignature(signature)
        }
    }

}


extension OpenSSHSignatureWriter {

    func ecdsaSignature(_ rawRepresentation: Data, keyType: KeyType) -> Data {
        let rawLength = rawRepresentation.count/2
        // Check if we need to pad with 0x00 to prevent certain
        // ssh servers from thinking r or s is negative
        let paddingRange: ClosedRange<UInt8> = 0x80...0xFF
        var r = Data(rawRepresentation[0..<rawLength])
        if paddingRange ~= r.first! {
            r.insert(0x00, at: 0)
        }
        var s = Data(rawRepresentation[rawLength...])
        if paddingRange ~= s.first! {
            s.insert(0x00, at: 0)
        }

        var signatureChunk = Data()
        signatureChunk.append(r.lengthAndData)
        signatureChunk.append(s.lengthAndData)
        var mutSignedData = Data()
        var sub = Data()
        sub.append(OpenSSHPublicKeyWriter().openSSHIdentifier(for: keyType).lengthAndData)
        sub.append(signatureChunk.lengthAndData)
        mutSignedData.append(sub.lengthAndData)
        return mutSignedData
    }

    func rsaSignature(_ rawRepresentation: Data) -> Data {
        var mutSignedData = Data()
        var sub = Data()
        sub.append("rsa-sha2-512".lengthAndData)
        sub.append(rawRepresentation.lengthAndData)
        mutSignedData.append(sub.lengthAndData)
        return mutSignedData
    }

}
