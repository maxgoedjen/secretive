import Foundation
import SecretAgentKit
import Brief
import XPCWrappers

/// Delegates all agent input parsing to an XPC service which wraps OpenSSH
public final class XPCAgentInputParser: SSHAgentInputParserProtocol {

    private let session: XPCTypedSession<SSHAgent.Request, SSHAgentInputParser.AgentParsingError>

    public init() throws {
        session = try XPCTypedSession(serviceName: "com.maxgoedjen.Secretive.SecretAgentInputParser", warmup: true)
    }

    public func parse(data: Data) async throws -> SSHAgent.Request {
        try await session.send(data)
    }

    deinit {
        session.complete()
    }

}
