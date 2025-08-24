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
            fatalError()
        case .mldsa:
            // https://www.ietf.org/archive/id/draft-sfluhrer-ssh-mldsa-04.txt
            fatalError()
        case .rsa:
            // https://datatracker.ietf.org/doc/html/rfc4253#section-6.6
            fatalError()
        }
    }

}

extension OpenSSHSignatureWriter {


    /// The fully qualified OpenSSH identifier for the algorithm.
    /// - Parameters:
    ///   - algorithm: The algorithm to identify.
    ///   - length: The key length of the algorithm.
    /// - Returns: The OpenSSH identifier for the algorithm.
    public func openSSHIdentifier(for keyType: KeyType) -> String {
        switch (keyType.algorithm, keyType.size) {
        case (.ecdsa, 256), (.ecdsa, 384):
            "ecdsa-sha2-nistp" + String(describing: keyType.size)
        case (.mldsa, 65), (.mldsa, 87):
            "ssh-mldsa-" + String(describing: keyType.size)
        case (.rsa, _):
            "ssh-rsa"
        default:
            "unknown"
        }
    }

}

extension OpenSSHSignatureWriter {

    public func rsaPublicKeyBlob<SecretType: Secret>(secret: SecretType) -> Data {
        // Cheap way to pull out e and n as defined in https://datatracker.ietf.org/doc/html/rfc4253
        // Keychain stores it as a thin ASN.1 wrapper with this format:
        // [4 byte prefix][2 byte prefix][n][2 byte prefix][e]
        // Rather than parse out the whole ASN.1 blob, we'll cheat and pull values directly since
        // we only support one key type, and the keychain always gives it in a specific format.
        let keySize = secret.keyType.size
        guard secret.keyType.algorithm == .rsa && keySize == 2048 else { fatalError() }
        let length = secret.keyType.size/8
        let data = secret.publicKey
        let n = Data(data[8..<(9+length)])
        let e = Data(data[(2+9+length)...])
        return e.lengthAndData + n.lengthAndData
    }

}
