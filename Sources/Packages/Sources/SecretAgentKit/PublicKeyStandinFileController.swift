import Foundation
import OSLog
import SecretKit
import SSHProtocolKit
import Common

/// Controller responsible for writing public keys to disk, so that they're easily accessible by scripts.
public final class PublicKeyFileStoreController: Sendable {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "PublicKeyFileStoreController")
    private let directory: URL
    private let keyWriter = OpenSSHPublicKeyWriter()
    private let publicKeyReader = OpenSSHPublicKeyReader()
    private let certificateReader = OpenSSHCertificateReader()

    /// Initializes a PublicKeyFileStoreController.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Writes out the keys specified to disk.
    /// - Parameter secrets: The Secrets to generate keys for.
    /// - Parameter clear: Whether or not any untracked files in the directory should be removed.
    public func generatePublicKeys(for secrets: [AnySecret], clear: Bool = false) throws {
        logger.log("Writing public keys to disk")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        let trackedPublicKeyFilenames = Set(secrets.map(generatedPublicKeyFilename(for:)))

        for secret in secrets {
            let path = URL.publicKeyPath(for: secret, in: directory)
            let data = Data(keyWriter.openSSHString(secret: secret).utf8)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }

        removeLegacyManifestIfNeeded()
        if clear {
            try pruneManagedArtifacts(trackedPublicKeyFilenames: trackedPublicKeyFilenames)
        }
        logger.log("Finished writing public keys")
    }

}

extension PublicKeyFileStoreController {
    private static let legacyManifestFilename = ".secretive-generated-public-keys"

    private func generatedPublicKeyFilename(for secret: AnySecret) -> String {
        URL(fileURLWithPath: URL.publicKeyPath(for: secret, in: directory)).lastPathComponent
    }

    private func pruneManagedArtifacts(trackedPublicKeyFilenames: Set<String>) throws {
        let fileURLs = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var activeKeysByFingerprint: [String: URL] = [:]
        var activeCertificatesByFingerprint: [String: [URL]] = [:]

        for fileURL in fileURLs {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }

            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                logger.warning("Failed to read public key artifact at \(fileURL.lastPathComponent, privacy: .public)")
                continue
            }

            if let parsedPublicKey = parsedPublicKey(from: contents) {
                if trackedPublicKeyFilenames.contains(fileURL.lastPathComponent) {
                    activeKeysByFingerprint[parsedPublicKey.fingerprint] = fileURL
                } else {
                    removeItemIfNeeded(
                        at: fileURL,
                        successMessage: "Removed stale generated public key at \(fileURL.lastPathComponent)",
                        failureMessage: "Failed to remove stale generated public key at \(fileURL.lastPathComponent)"
                    )
                }
                continue
            }

            guard let parsedCertificate = parsedCertificate(from: contents) else {
                continue
            }

            if parsedCertificate.isExpired() {
                removeItemIfNeeded(
                    at: fileURL,
                    successMessage: "Removed expired certificate at \(fileURL.lastPathComponent)",
                    failureMessage: "Failed to remove expired certificate at \(fileURL.lastPathComponent)"
                )
                continue
            }

            activeCertificatesByFingerprint[parsedCertificate.subjectKeyFingerprint, default: []].append(fileURL)
        }

        for (fingerprint, certificateURLs) in activeCertificatesByFingerprint where activeKeysByFingerprint[fingerprint] == nil {
            for certificateURL in certificateURLs {
                removeItemIfNeeded(
                    at: certificateURL,
                    successMessage: "Removed orphaned certificate at \(certificateURL.lastPathComponent)",
                    failureMessage: "Failed to remove orphaned certificate at \(certificateURL.lastPathComponent)"
                )
            }
        }
    }

    private func parsedPublicKey(from contents: String) -> OpenSSHPublicKeyReader.ParsedPublicKey? {
        try? publicKeyReader.readPublicKeyLine(contents)
    }

    private func parsedCertificate(from contents: String) -> OpenSSHCertificateReader.ParsedCertificate? {
        try? certificateReader.readPublicKeyLine(contents)
    }

    private func removeLegacyManifestIfNeeded() {
        let manifestURL = directory.appending(path: Self.legacyManifestFilename)
        guard FileManager.default.fileExists(atPath: manifestURL.path()) else {
            return
        }

        removeItemIfNeeded(
            at: manifestURL,
            successMessage: "Removed legacy generated public key manifest",
            failureMessage: "Failed to remove legacy generated public key manifest"
        )
    }

    private func removeItemIfNeeded(at fileURL: URL, successMessage: String, failureMessage: String) {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            logger.log("\(successMessage, privacy: .public)")
        } catch {
            logger.warning("\(failureMessage, privacy: .public)")
        }
    }

}
