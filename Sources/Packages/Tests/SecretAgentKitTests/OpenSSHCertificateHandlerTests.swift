import Foundation
import Testing
import SSHProtocolKit
@testable import SecretAgentKit

@Suite struct OpenSSHCertificateHandlerTests {

    @Test func multipleCertificatesForSingleSecretAreEnumeratedInStableOrder() async throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(for: CertificateTestFixtures.ecdsa256Secret, comment: "Alpha cert"),
            to: directory.appending(path: "alpha-access")
        )
        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(for: CertificateTestFixtures.ecdsa256Secret, comment: "Beta cert with spaces"),
            to: directory.appending(path: "omega-access.pub")
        )
        try CertificateTestFixtures.write(
            CertificateTestFixtures.writer.openSSHString(secret: CertificateTestFixtures.ecdsa256Secret),
            to: directory.appending(path: "plain-key.pub")
        )

        let handler = OpenSSHCertificateHandler(directory: directory)
        await handler.reloadCertificates()
        let identities = await handler.certificateIdentities(for: CertificateTestFixtures.ecdsa256Secret)
        let certificateReader = OpenSSHCertificateReader()
        let expectedFingerprint = CertificateTestFixtures.writer.openSSHSHA256Fingerprint(secret: CertificateTestFixtures.ecdsa256Secret)

        #expect(identities.count == 2)
        #expect(String(decoding: identities[0].comment, as: UTF8.self) == "Alpha cert")
        #expect(String(decoding: identities[1].comment, as: UTF8.self) == "Beta cert with spaces")
        #expect(try identities.allSatisfy { try certificateReader.readCertificateBlob($0.keyBlob).subjectKeyFingerprint == expectedFingerprint })
    }

    @Test func certificateFilesAreMatchedByEmbeddedFingerprintNotFilename() async throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(for: CertificateTestFixtures.ecdsa256Secret, comment: "Primary cert"),
            to: directory.appending(path: "looks-like-secondary.pub")
        )

        let handler = OpenSSHCertificateHandler(directory: directory)
        await handler.reloadCertificates()

        let primaryIdentities = await handler.certificateIdentities(for: CertificateTestFixtures.ecdsa256Secret)
        let secondaryIdentities = await handler.certificateIdentities(for: CertificateTestFixtures.ecdsa384Secret)

        #expect(primaryIdentities.count == 1)
        #expect(secondaryIdentities.isEmpty)
    }

    @Test func certificateCacheClearsWhenFilesDisappear() async throws {
        let directory = try CertificateTestFixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let certificateURL = directory.appending(path: "temporary-cert.pub")
        try CertificateTestFixtures.write(
            CertificateTestFixtures.certificateLine(for: CertificateTestFixtures.ecdsa256Secret, comment: "Ephemeral cert"),
            to: certificateURL
        )

        let handler = OpenSSHCertificateHandler(directory: directory)
        await handler.reloadCertificates()
        #expect(await handler.certificateIdentities(for: CertificateTestFixtures.ecdsa256Secret).count == 1)

        try FileManager.default.removeItem(at: certificateURL)
        await handler.reloadCertificates()

        #expect(await handler.certificateIdentities(for: CertificateTestFixtures.ecdsa256Secret).isEmpty)
    }

}
