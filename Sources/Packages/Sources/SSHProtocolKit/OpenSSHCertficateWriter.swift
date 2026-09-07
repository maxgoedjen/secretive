import Foundation
import CryptoKit
import CertificateKit
import Formatters

/// Generates OpenSSH representations of Certificates.
public struct OpenSSHCertificateWriter: Sendable {

    /// Initializes the writer.
    public init() {
    }

    /// Generates an OpenSSH data payload identifying the certificate.
    /// - Returns: OpenSSH data payload identifying the certificate.
    public func data(publicKey: OpenSSHCertificate.PublicKey) -> Data {
        // https://datatracker.ietf.org/doc/html/rfc5656#section-3.1
        publicKey.keyType.lengthAndData +
        publicKey.curveName.lengthAndData +
        publicKey.data.lengthAndData
    }

    /// Generates an OpenSSH SHA256 fingerprint string.
    /// - Returns: OpenSSH SHA256 fingerprint string.
    public func openSSHSHA256KeyFingerprint(publicKey: OpenSSHCertificate.PublicKey) -> String {
        // OpenSSL format seems to strip the padding at the end.
        let cleaned = SHA256.hash(data: data(publicKey: publicKey)).formatted(.base64(stripPadding: true))
        return "SHA256:\(cleaned)"
    }

}
