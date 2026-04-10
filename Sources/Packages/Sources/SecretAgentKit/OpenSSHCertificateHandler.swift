import Foundation
import OSLog
import SecretKit
import SSHProtocolKit
import Common

/// Manages storage and lookup for OpenSSH certificates.
public actor OpenSSHCertificateHandler: Sendable {
    private let directory: URL
    private let certificateReader: OpenSSHCertificateReader
    private let publicKeyWriter: OpenSSHPublicKeyWriter
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "OpenSSHCertificateHandler")
    private var certificatesByFingerprint: [String: [OpenSSHCertificateReader.ParsedCertificate]] = [:]

    /// Initializes an OpenSSHCertificateHandler.
    public init(
        directory: URL = URL.publicKeyDirectory,
        certificateReader: OpenSSHCertificateReader = .init(),
        publicKeyWriter: OpenSSHPublicKeyWriter = .init()
    ) {
        self.directory = directory
        self.certificateReader = certificateReader
        self.publicKeyWriter = publicKeyWriter
    }

    /// Reloads any certificates in the PublicKeys folder.
    public func reloadCertificates() {
        certificatesByFingerprint = [:]

        let fileURLs: [URL]
        do {
            fileURLs = try FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            logger.debug("No readable certificate directory found at \(self.directory.path(), privacy: .public)")
            return
        }

        for fileURL in fileURLs {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else {
                    continue
                }

                let contents = try String(contentsOf: fileURL, encoding: .utf8)
                let parsedCertificate = try certificateReader.readPublicKeyLine(contents)
                certificatesByFingerprint[parsedCertificate.subjectKeyFingerprint, default: []].append(
                    parsedCertificate
                )
            } catch OpenSSHCertificateReader.OpenSSHCertificateError.unsupportedType,
                OpenSSHCertificateReader.OpenSSHCertificateError.invalidPublicKeyLine {
                continue
            } catch {
                logger.warning("Failed to load certificate from \(fileURL.lastPathComponent, privacy: .public)")
            }
        }
    }

    /// Returns all certificates that correspond to a ``Secret``.
    /// - Parameter secret: The secret to search for certificates with.
    /// - Returns: The certificate identities that correspond to the secret.
    public func certificateIdentities<SecretType: Secret>(for secret: SecretType) -> [OpenSSHCertificateIdentity] {
        let fingerprint = publicKeyWriter.openSSHSHA256Fingerprint(secret: secret)
        return certificatesByFingerprint[fingerprint, default: []].map {
            OpenSSHCertificateIdentity(
                keyBlob: $0.certificateBlob,
                comment: Data(($0.comment ?? secret.name).utf8)
            )
        }
    }

}

extension OpenSSHCertificateHandler {

    /// An OpenSSH certificate identity advertised by the agent.
    public struct OpenSSHCertificateIdentity: Sendable, Hashable {
        public let keyBlob: Data
        public let comment: Data

        init(keyBlob: Data, comment: Data) {
            self.keyBlob = keyBlob
            self.comment = comment
        }
    }

}
