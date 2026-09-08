import Foundation
import Security
import CryptoTokenKit
import CryptoKit
import os
import SSHProtocolKit
import CertificateKit

public struct CertificateMigrator {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.migration", category: "CertificateKitMigrator")
    private let publicKeysDirectory: URL
    private let certificatesDirectory: URL
    private let certificateStore: CertificateStore

    /// Initializes a PublicKeyFileStoreController.
    public init(homeDirectory: URL, certificateStore: CertificateStore) {
        publicKeysDirectory = homeDirectory.appending(component: "PublicKeys")
        certificatesDirectory = homeDirectory.appending(component: "Certificates")
        self.certificateStore = certificateStore
    }

    @MainActor public func migrate() throws {
        try migrate(directory: publicKeysDirectory)
        try migrate(directory: certificatesDirectory)
    }

    @MainActor public func migrate(directory: URL) throws {
        let fileCerts = try FileManager.default
            .contentsOfDirectory(atPath: directory.path())
            .filter { $0.hasSuffix("-cert.pub") }
        Task {
            for path in fileCerts {
                do {
                    let url = directory.appending(component: path)
                    let data = try Data(contentsOf: url)
                    let parser = try await XPCCertificateParser()
                    let cert = try await parser.parse(data: data)
                    try certificateStore.save(certificate: Certificate(openSSHCertificate: cert, rawData: data))
                    do {
                        try FileManager.default.removeItem(at: url)
                    } catch {
                        logger.error("Failed to delete successfully migrated cert: \(path)")
                    }
                } catch {
                    logger.error("Failed to migrate cert: \(path)")
                }
            }

        }
    }

}
