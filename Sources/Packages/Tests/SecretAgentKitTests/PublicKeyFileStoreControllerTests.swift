import Foundation
import Testing
import SecretKit
@testable import SecretAgentKit
import Common

@Suite struct PublicKeyFileStoreControllerTests {

    @Test func clearGeneratedPublicKeysRemovesExpiredCertificates() throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let controller = PublicKeyFileStoreController(directory: directory)
        let activeSecret = AnySecret(CertificateTestFixtures.ecdsa256Secret)
        let expiredCertificateURL = directory.appending(path: "expired-access-cert.pub")

        try controller.generatePublicKeys(for: [activeSecret], clear: false)
        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(
                for: CertificateTestFixtures.ecdsa256Secret,
                comment: "Expired certificate",
                validBefore: 1
            ),
            to: expiredCertificateURL
        )

        try controller.generatePublicKeys(for: [activeSecret], clear: true)

        #expect(!FileManager.default.fileExists(atPath: expiredCertificateURL.path()))
    }

    @Test func clearGeneratedPublicKeysRemovesCertificatesForMissingKeys() throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let controller = PublicKeyFileStoreController(directory: directory)
        let activeSecret = AnySecret(CertificateTestFixtures.ecdsa256Secret)
        let orphanedCertificateURL = directory.appending(path: "orphaned-access-cert.pub")

        try controller.generatePublicKeys(for: [activeSecret], clear: false)
        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(
                for: CertificateTestFixtures.ecdsa384Secret,
                comment: "Orphaned certificate",
                validBefore: 4_102_444_800
            ),
            to: orphanedCertificateURL
        )

        try controller.generatePublicKeys(for: [activeSecret], clear: true)

        #expect(!FileManager.default.fileExists(atPath: orphanedCertificateURL.path()))
    }

    @Test func clearGeneratedPublicKeysKeepsNonExpiredCertificatesForActiveKeys() throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let controller = PublicKeyFileStoreController(directory: directory)
        let activeSecret = AnySecret(CertificateTestFixtures.ecdsa256Secret)
        let activeCertificateURL = directory.appending(path: "active-access-cert.pub")

        try controller.generatePublicKeys(for: [activeSecret], clear: false)
        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(
                for: CertificateTestFixtures.ecdsa256Secret,
                comment: "Active certificate",
                validBefore: 4_102_444_800
            ),
            to: activeCertificateURL
        )

        try controller.generatePublicKeys(for: [activeSecret], clear: true)

        #expect(FileManager.default.fileExists(atPath: URL.publicKeyPath(for: activeSecret, in: directory)))
        #expect(FileManager.default.fileExists(atPath: activeCertificateURL.path()))
    }

    @Test func clearGeneratedPublicKeysRemovesStaleGeneratedPublicKeys() throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let controller = PublicKeyFileStoreController(directory: directory)
        let originalSecret = AnySecret(CertificateTestFixtures.ecdsa256Secret)
        let replacementSecret = AnySecret(CertificateTestFixtures.ecdsa384Secret)
        let originalPath = URL.publicKeyPath(for: originalSecret, in: directory)
        let replacementPath = URL.publicKeyPath(for: replacementSecret, in: directory)

        try controller.generatePublicKeys(for: [originalSecret], clear: false)
        try controller.generatePublicKeys(for: [replacementSecret], clear: true)

        #expect(!FileManager.default.fileExists(atPath: originalPath))
        #expect(FileManager.default.fileExists(atPath: replacementPath))
    }

}
