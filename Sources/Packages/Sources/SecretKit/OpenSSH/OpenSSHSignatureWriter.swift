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
        case .mldsa:
            // https://datatracker.ietf.org/doc/html/draft-sfluhrer-ssh-mldsa-00#name-public-key-algorithms
            mldsaSignature(signature, keyType: secret.keyType)
        case .rsa:
            // https://datatracker.ietf.org/doc/html/rfc4253#section-6.6
            rsaSignature(signature)
        }
    }

}


extension OpenSSHSignatureWriter {

    /// Converts a fixed-width big-endian integer (e.g. r/s from CryptoKit rawRepresentation) into an SSH mpint.
    /// Strips unnecessary leading zeros and prefixes `0x00` if needed to keep the value positive.
    private func mpint(fromFixedWidthPositiveBytes bytes: Data) -> Data {
        // mpint zero is encoded as a string with zero bytes of data.
        guard let firstNonZeroIndex = bytes.firstIndex(where: { $0 != 0x00 }) else {
            return Data()
        }

        let trimmed = Data(bytes[firstNonZeroIndex...])

        if let first = trimmed.first, first >= 0x80 {
            var prefixed = Data([0x00])
            prefixed.append(trimmed)
            return prefixed
        }
        return trimmed
    }

    func ecdsaSignature(_ rawRepresentation: Data, keyType: KeyType) -> Data {
        let rawLength = rawRepresentation.count/2
        let r = mpint(fromFixedWidthPositiveBytes: Data(rawRepresentation[0..<rawLength]))
        let s = mpint(fromFixedWidthPositiveBytes: Data(rawRepresentation[rawLength...]))

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

    func mldsaSignature(_ rawRepresentation: Data, keyType: KeyType) -> Data {
        var mutSignedData = Data()
        var sub = Data()
        sub.append(OpenSSHPublicKeyWriter().openSSHIdentifier(for: keyType).lengthAndData)
        sub.append(rawRepresentation.lengthAndData)
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
