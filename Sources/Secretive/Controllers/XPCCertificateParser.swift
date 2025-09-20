import Foundation
import OSLog
import SSHProtocolKit
import Brief
import XPCWrappers

/// Delegates all agent input parsing to an XPC service which wraps OpenSSH
public final class XPCCertificateParser: OpenSSHCertificateParserProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive", category: "XPCCertificateParser")
    private let session: XPCTypedSession<OpenSSHCertificate, OpenSSHCertificateError>

    public init() async throws {
        logger.debug("Creating XPCCertificateParser")
        session = try await XPCTypedSession(serviceName: "com.maxgoedjen.Secretive.SecretiveCertificateParser", warmup: true)
        logger.debug("XPCCertificateParser is warmed up.")
    }

    public func parse(data: Data) async throws -> OpenSSHCertificate {
        logger.debug("Parsing input")
        defer { logger.debug("Parsed input") }
        return try await session.send(data)
    }

    deinit {
        session.complete()
    }

}
