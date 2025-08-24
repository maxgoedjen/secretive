import Foundation
import CryptoKit

/// Generates OpenSSH representations of Secrets.
public struct OpenSSHKeyWriter: Sendable {

    /// Initializes the writer.
    public init() {
    }

    /// Generates an OpenSSH data payload identifying the secret.
    /// - Returns: OpenSSH data payload identifying the secret.
    public func data<SecretType: Secret>(secret: SecretType) -> Data {
        if secret.keyType.algorithm == .ecdsa {
            lengthAndData(of: Data(curveType(for: secret.keyType).utf8)) +
            lengthAndData(of: Data(curveIdentifier(for: secret.keyType).utf8)) +
            lengthAndData(of: secret.publicKey)
        } else {
            lengthAndData(of: Data(curveType(for: secret.keyType).utf8)) +
            lengthAndData(of: secret.publicKey)
        }
    }

    /// Generates an OpenSSH string representation of the secret.
    /// - Returns: OpenSSH string representation of the secret.
    public func openSSHString<SecretType: Secret>(secret: SecretType) -> String {
        let resolvedComment: String
        if let comment = secret.publicKeyAttribution {
            resolvedComment = comment
        } else {
            let dashedKeyName = secret.name.replacingOccurrences(of: " ", with: "-")
            let dashedHostName = ["secretive", Host.current().localizedName, "local"]
                .compactMap { $0 }
                .joined(separator: ".")
                .replacingOccurrences(of: " ", with: "-")
            resolvedComment = "\(dashedKeyName)@\(dashedHostName)"
        }
        return [curveType(for: secret.keyType), data(secret: secret).base64EncodedString(), resolvedComment]
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

}

extension OpenSSHKeyWriter {

    /// Creates an OpenSSH protocol style data object, which has a length header, followed by the data payload.
    /// - Parameter data: The data payload.
    /// - Returns: OpenSSH data.
    public func lengthAndData(of data: Data) -> Data {
        let rawLength = UInt32(data.count)
        var endian = rawLength.bigEndian
        return Data(bytes: &endian, count: UInt32.bitWidth/8) + data
    }

    /// The fully qualified OpenSSH identifier for the algorithm.
    /// - Parameters:
    ///   - algorithm: The algorithm to identify.
    ///   - length: The key length of the algorithm.
    /// - Returns: The OpenSSH identifier for the algorithm.
    public func curveType(for keyType: KeyType) -> String {
        switch (keyType.algorithm, keyType.size) {
        case (.ecdsa, 256), (.ecdsa, 384):
            "ecdsa-sha2-nistp" + String(describing: keyType.size)
        case (.mldsa, 65), (.mldsa, 87):
            "ssh-mldsa" + String(describing: keyType.size)
        case (.rsa, _):
            // All RSA keys use the same 512 bit hash function, per
            // https://security.stackexchange.com/questions/255074/why-are-rsa-sha2-512-and-rsa-sha2-256-supported-but-not-reported-by-ssh-q-key
             "rsa-sha2-512"
        default:
            "unknown"
        }
    }

    /// The OpenSSH identifier for an algorithm.
    /// - Parameters:
    ///   - algorithm: The algorithm to identify.
    ///   - length: The key length of the algorithm.
    /// - Returns: The OpenSSH identifier for the algorithm.
    private func curveIdentifier(for keyType: KeyType) -> String {
        switch keyType.algorithm {
        case .ecdsa:
            "nistp" + String(describing: keyType.size)
        case .mldsa:
            "mldsa" + String(describing: keyType.size)
        case .rsa:
            // All RSA keys use the same 512 bit hash function
            "rsa-sha2-512"
        }
    }

}
