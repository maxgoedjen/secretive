import Foundation
import OSLog
import SecretKit
import SSHProtocolKit

/// Manages storage and lookup for OpenSSH certificates.
public actor OpenSSHCertificateHandler: Sendable {

    private let publicKeyFileStoreController = PublicKeyFileStoreController(homeDirectory: URL.homeDirectory)
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
    }

    /// Attempts to find an OpenSSH Certificate  that corresponds to a ``Secret``
    /// - Parameter secret: The secret to search for a certificate with
    /// - Returns: A (``Data``, ``Data``) tuple containing the certificate and certificate name, respectively.
    public func keyBlobAndName<SecretType: Secret>(for secret: SecretType) throws -> (Data, Data)? {
        keyBlobsAndNames[AnySecret(secret)]
    }

}

