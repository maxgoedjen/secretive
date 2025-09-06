import Foundation
import SecretAgentKit

public final class XPCAgentInputParser: SSHAgentInputParserProtocol {

    private let session: XPCSession
    private let queue = DispatchQueue(label: "com.maxgoedjen.Secretive.AgentRequestParser", qos: .userInteractive)

    public init() throws {
        if #available(macOS 26.0, *) {
            session = try XPCSession(xpcService: "com.maxgoedjen.Secretive.AgentRequestParser", targetQueue: queue, options: .inactive, requirement: .isFromSameTeam())
        } else {
            session = try XPCSession(xpcService: "com.maxgoedjen.Secretive.AgentRequestParser", targetQueue: queue, options: .inactive)
        }
        try session.activate()
    }

    public func parse(data: Data) async throws -> SSHAgent.Request {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try session.send(data) { result in
                    switch result {
                    case .success(let result):
                        do {
                            continuation.resume(returning: try result.decode(as: SSHAgent.Request.self))
                        } catch {
                            continuation.resume(throwing: error)
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

}
