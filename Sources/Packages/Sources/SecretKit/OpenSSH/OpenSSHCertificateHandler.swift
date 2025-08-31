import Foundation
import OSLog

/// Manages storage and lookup for OpenSSH certificates.
public actor OpenSSHCertificateHandler: Sendable {

    private let publicKeyFileStoreController = PublicKeyFileStoreController(homeDirectory: NSHomeDirectory())
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "OpenSSHCertificateHandler")
    private let writer = OpenSSHPublicKeyWriter()
    private var keyBlobsAndNames: [AnySecret: (Data, Data)] = [:]

    /// Initializes an OpenSSHCertificateHandler.
    public init() {
    }

    /// Reloads any certificates in the PublicKeys folder.
    /// - Parameter secrets: the secrets to look up corresponding certificates for.
    public func reloadCertificates(for secrets: [AnySecret]) {
        guard publicKeyFileStoreController.hasAnyCertificates else {
            logger.log("No certificates, short circuiting")
            return
        }
        keyBlobsAndNames = secrets.reduce(into: [:]) { partialResult, next in
            partialResult[next] = try? loadKeyblobAndName(for: next)
        }
    }

    /// Reconstructs a public key from a ``Data``, if that ``Data`` contains an OpenSSH certificate hash. Currently only ecdsa certificates are supported
    /// - Parameter certBlock: The openssh certificate to extract the public key from
    /// - Returns: A ``Data`` object containing the public key in OpenSSH wire format if the ``Data`` is an OpenSSH certificate hash, otherwise nil.
    public func publicKeyHash(from hash: Data) -> Data? {
        let reader = OpenSSHReader(data: hash)
        do {
            let certType = String(decoding: try reader.readNextChunk(), as: UTF8.self)
            switch certType {
            case "ecdsa-sha2-nistp256-cert-v01@openssh.com",
                "ecdsa-sha2-nistp384-cert-v01@openssh.com",
                "ecdsa-sha2-nistp521-cert-v01@openssh.com":
                _ = try reader.readNextChunk() // nonce
                let curveIdentifier = try reader.readNextChunk()
                let publicKey = try reader.readNextChunk()

                let openSSHIdentifier = certType.replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
                return openSSHIdentifier.lengthAndData +
                curveIdentifier.lengthAndData +
                publicKey.lengthAndData
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

    /// Attempts to find an OpenSSH Certificate  that corresponds to a ``Secret``
    /// - Parameter secret: The secret to search for a certificate with
    /// - Returns: A (``Data``, ``Data``) tuple containing the certificate and certificate name, respectively.
    public func keyBlobAndName<SecretType: Secret>(for secret: SecretType) throws -> (Data, Data)? {
        keyBlobsAndNames[AnySecret(secret)]
    }
    
    /// Attempts to find an OpenSSH Certificate  that corresponds to a ``Secret``
    /// - Parameter secret: The secret to search for a certificate with
    /// - Returns: A (``Data``, ``Data``) tuple containing the certificate and certificate name, respectively.
    private func loadKeyblobAndName<SecretType: Secret>(for secret: SecretType) throws -> (Data, Data)? {
        let certificatePath = publicKeyFileStoreController.sshCertificatePath(for: secret)
        guard FileManager.default.fileExists(atPath: certificatePath) else {
            return nil
        }

        logger.debug("Found certificate for \(secret.name)")
        let certContent = try String(contentsOfFile:certificatePath, encoding: .utf8)
        let certElements = certContent.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")

        guard certElements.count >= 2 else {
            logger.warning("Certificate found for \(secret.name) but failed to load")
            throw OpenSSHCertificateError.parsingFailed
        }
        guard let certDecoded = Data(base64Encoded: certElements[1] as String)  else {
            logger.warning("Certificate found for \(secret.name) but failed to decode base64 key")
            throw OpenSSHCertificateError.parsingFailed
        }

        if certElements.count >= 3 {
            let certName = Data(certElements[2].utf8)
            return (certDecoded, certName)
        }
        let certName = Data(secret.name.utf8)
        logger.info("Certificate for \(secret.name) does not have a name tag, using secret name instead")
        return (certDecoded, certName)
    }

}

extension OpenSSHCertificateHandler {

    enum OpenSSHCertificateError: LocalizedError {
        case unsupportedType
        case parsingFailed
        case doesNotExist

        public var errorDescription: String? {
            switch self {
            case .unsupportedType:
                return "The key type was unsupported"
            case .parsingFailed:
                return "Failed to properly parse the SSH certificate"
            case .doesNotExist:
                return "Certificate does not exist"
            }
        }
    }

}
