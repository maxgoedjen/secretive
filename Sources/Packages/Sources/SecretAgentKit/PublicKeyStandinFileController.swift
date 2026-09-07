import Foundation
import OSLog
import SecretKit
import SSHProtocolKit
import CertificateKit
import Common

/// Controller responsible for writing public keys to disk, so that they're easily accessible by scripts.
public final class PublicKeyFileStoreController: Sendable {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "PublicKeyFileStoreController")
    private let publicKeysURL: URL
    private let certificatesURL: URL
    private let keyWriter = OpenSSHPublicKeyWriter()

    /// Initializes a PublicKeyFileStoreController.
    public init(publicKeysURL: URL, certificatesURL: URL) {
        self.publicKeysURL = publicKeysURL
        self.certificatesURL = certificatesURL
    }

    /// Writes out the keys specified to disk.
    /// - Parameter secrets: The Secrets to generate keys for.
    /// - Parameter clear: Whether or not any untracked files in the directory should be removed.
    public func generatePublicKeys(for secrets: [AnySecret], clear: Bool = false) throws {
        logger.log("Writing public keys to disk")
        if clear {
            let validPaths = Set(secrets.map { URL.publicKeyPath(for: $0, in: publicKeysURL) })
                .union(Set(secrets.map { legacySSHCertificatePath(for: $0) }))
            let contentsOfDirectory = (try? FileManager.default.contentsOfDirectory(atPath: publicKeysURL.path())) ?? []
            let fullPathContents = contentsOfDirectory.map { publicKeysURL.appending(path: $0).path() }

            let untracked = Set(fullPathContents)
                .subtracting(validPaths)
            for path in untracked {
                // string instead of fileURLWithPath since we're already using fileURL format.
                try? FileManager.default.removeItem(at: URL(string: path)!)
            }
        }
        try? FileManager.default.createDirectory(at: publicKeysURL, withIntermediateDirectories: false, attributes: nil)
        for secret in secrets {
            let path = URL.publicKeyPath(for: secret, in: publicKeysURL)
            let data = Data(keyWriter.openSSHString(secret: secret).utf8)
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
        logger.log("Finished writing public keys")
    }

    /// Writes out the certificates specified to disk.
    /// - Parameter certificates: The Secrets to generate keys for.
    /// - Parameter clear: Whether or not any untracked files in the directory should be removed.
    public func generateCertificates(for certificates: [Certificate], clear: Bool = false) throws {
        logger.log("Writing certificates to disk")
        if clear {
            let validPaths = Set(certificates.map { URL.certificatePath(for: $0.id, in: certificatesURL) })
            let contentsOfDirectory = (try? FileManager.default.contentsOfDirectory(atPath: certificatesURL.path())) ?? []
            let fullPathContents = contentsOfDirectory.map { certificatesURL.appending(path: $0).path() }

            let untracked = Set(fullPathContents)
                .subtracting(validPaths)
            for path in untracked {
                // string instead of fileURLWithPath since we're already using fileURL format.
                try? FileManager.default.removeItem(at: URL(string: path)!)
            }
        }
        try? FileManager.default.createDirectory(at: certificatesURL, withIntermediateDirectories: false, attributes: nil)
        for certificate in certificates {
            let path = URL.certificatePath(for: certificate.id, in: certificatesURL)
            FileManager.default.createFile(atPath: path, contents: certificate.rawData, attributes: nil)
        }
        logger.log("Finished writing certificates")
    }

    /// The path for a Secret's SSH Certificate public key.
    /// - Parameter secret: The Secret to return the path for.
    /// - Returns: The path to the SSH Certificate public key.
    /// - Warning: This method returning a path does not imply that a key has a SSH certificates. This method only describes where it will be.
    private func legacySSHCertificatePath<SecretType: Secret>(for secret: SecretType) -> String {
        let minimalHex = keyWriter.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        return publicKeysURL.appending(component: "\(minimalHex).pub").path()
    }

}
