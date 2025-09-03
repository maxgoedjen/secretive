import Foundation
import CryptoKit

/// Generates OpenSSH representations of the public key sof secrets.
public struct OpenSSHPublicKeyWriter: Sendable {

    /// Initializes the writer.
    public init() {
    }

    /// Generates an OpenSSH data payload identifying the secret.
    /// - Returns: OpenSSH data payload identifying the secret.
    public func data<SecretType: Secret>(secret: SecretType) -> Data {
        switch secret.keyType.algorithm {
        case .ecdsa:
            // https://datatracker.ietf.org/doc/html/rfc5656#section-3.1
            openSSHIdentifier(for: secret.keyType).lengthAndData +
            ("nistp" + String(describing: secret.keyType.size)).lengthAndData +
            secret.publicKey.lengthAndData
        case .mldsa:
            // https://www.ietf.org/archive/id/draft-sfluhrer-ssh-mldsa-04.txt
            openSSHIdentifier(for: secret.keyType).lengthAndData +
            secret.publicKey.lengthAndData
        case .rsa:
            // https://datatracker.ietf.org/doc/html/rfc4253#section-6.6
            openSSHIdentifier(for: secret.keyType).lengthAndData +
            rsaPublicKeyBlob(secret: secret)
        }
    }

    /// Generates an OpenSSH string representation of the secret.
    /// - Returns: OpenSSH string representation of the secret.
    public func openSSHString<SecretType: Secret>(secret: SecretType) -> String {
        return [openSSHIdentifier(for: secret.keyType), data(secret: secret).base64EncodedString(), comment(secret: secret)]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// Generates an OpenSSH SHA256 fingerprint string.
    /// - Returns: OpenSSH SHA256 fingerprint string.
    public func openSSHSHA256Fingerprint<SecretType: Secret>(secret: SecretType) -> String {
        // OpenSSL format seems to strip the padding at the end.
        let base64 = Data(SHA256.hash(data: data(secret: secret))).base64EncodedString()
        let paddingRange = base64.index(base64.endIndex, offsetBy: -2)..<base64.endIndex
        let cleaned = base64.replacingOccurrences(of: "=", with: "", range: paddingRange)
        return "SHA256:\(cleaned)"
    }

    /// Generates an OpenSSH MD5 fingerprint string.
    /// - Returns: OpenSSH MD5 fingerprint string.
    public func openSSHMD5Fingerprint<SecretType: Secret>(secret: SecretType) -> String {
        Insecure.MD5.hash(data: data(secret: secret))
            .compactMap { ("0" + String($0, radix: 16, uppercase: false)).suffix(2) }
            .joined(separator: ":")
    }

    public func comment<SecretType: Secret>(secret: SecretType) -> String {
        if let comment = secret.publicKeyAttribution {
            return comment
        } else {
            let dashedKeyName = secret.name.replacingOccurrences(of: " ", with: "-")
            let dashedHostName = ["secretive", Host.current().localizedName, "local"]
                .compactMap { $0 }
                .joined(separator: ".")
                .replacingOccurrences(of: " ", with: "-")
            return "\(dashedKeyName)@\(dashedHostName)"
        }

    }
}

extension OpenSSHPublicKeyWriter {

    /// The fully qualified OpenSSH identifier for the algorithm.
    /// - Parameters:
    ///   - algorithm: The algorithm to identify.
    ///   - length: The key length of the algorithm.
    /// - Returns: The OpenSSH identifier for the algorithm.
    public func openSSHIdentifier(for keyType: KeyType) -> String {
        switch keyType {
        case .ecdsa256:
            "ecdsa-sha2-nistp256"
        case .ecdsa384:
            "ecdsa-sha2-nistp384"
        case .mldsa65:
            "ssh-mldsa-65"
        case .mldsa87:
            "ssh-mldsa-87"
        case .rsa2048:
            "ssh-rsa"
        default:
            "unknown"
        }
    }

}

extension OpenSSHPublicKeyWriter {

    public func rsaPublicKeyBlob<SecretType: Secret>(secret: SecretType) -> Data {
        // Cheap way to pull out e and n as defined in https://datatracker.ietf.org/doc/html/rfc4253
        // Keychain stores it as a thin ASN.1 wrapper with this format:
        // [4 byte prefix][2 byte prefix][n][2 byte prefix][e]
        // Rather than parse out the whole ASN.1 blob, we'll cheat and pull values directly since
        // we only support one key type, and the keychain always gives it in a specific format.
        guard secret.keyType == .rsa2048 else { fatalError() }
        let length = secret.keyType.size/8
        let data = secret.publicKey
        let n = Data(data[8..<(9+length)])
        let e = Data(data[(2+9+length)...])
        return e.lengthAndData + n.lengthAndData
    }

}
