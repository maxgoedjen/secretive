import Foundation
import SecretAgentKit

/// Delegates all agent input parsing to an XPC service which wraps OpenSSH
public final class XPCAgentInputParser: SSHAgentInputParserProtocol {

    private let session: XPCSession
    private let queue = DispatchQueue(label: "com.maxgoedjen.Secretive.AgentRequestParser", qos: .userInteractive)

    public init() throws {
        if #available(macOS 26.0, *) {
            session = try XPCSession(xpcService: "com.maxgoedjen.Secretive.AgentRequestParser", targetQueue: queue, requirement: .isFromSameTeam())
        } else {
            session = try XPCSession(xpcService: "com.maxgoedjen.Secretive.AgentRequestParser", targetQueue: queue)
        }
        Task {
            // Warm up the XPC endpoint.
            _ = try? await parse(data: Data())

        }
    }

    public func parse(data: Data) async throws -> SSHAgent.Request {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try session.send(data) { result in
                    switch result {
                    case .success(let result):
                        if let result = try? result.decode(as: SSHAgent.Request.self) {
                            continuation.resume(returning: result)
                        } else if let error = try? result.decode(as: SSHAgentInputParser.AgentParsingError.self) {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(throwing: UnknownMessageError())
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    deinit {
        session.cancel(reason: "Done")
    }

    struct UnknownMessageError: Error {}

}
