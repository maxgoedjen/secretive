import Foundation
import SecretAgentKit
import Brief
import XPCWrappers
import OSLog
import SSHProtocolKit

/// Delegates all agent input parsing to an XPC service which wraps OpenSSH
public final class XPCAgentInputParser: SSHAgentInputParserProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "XPCAgentInputParser")
    private let session: XPCTypedSession<SSHAgent.Request, SSHAgentInputParser.AgentParsingError>

    public init() async throws {
        logger.debug("Creating XPCAgentInputParser")
        session = try await XPCTypedSession(serviceName: "com.maxgoedjen.Secretive.SecretAgentInputParser", warmup: true)
        logger.debug("XPCAgentInputParser is warmed up.")
    }

    public func parse(data: Data) async throws -> SSHAgent.Request {
        logger.debug("Parsing input")
        defer { logger.debug("Parsed input") }
        return try await session.send(data)
    }

    deinit {
        session.complete()
    }

}
