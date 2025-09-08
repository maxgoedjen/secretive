import Foundation
import XPC

@_silgen_name("xpc_session_set_peer_code_signing_requirement")
func xpc_session_set_peer_code_signing_requirement(_ session: Any, _ requirement: UnsafePointer<CChar>) -> Int32

public struct XPCTypedSession<ResponseType: Codable & Sendable, ErrorType: Error & Codable>: Sendable {

    private let session: XPCSession

    public init(serviceName: String, warmup: Bool = false) throws {
//        if #available(macOS 26.0, *) {
//            session = try XPCSession(xpcService: serviceName, requirement: .isFromSameTeam())
//        } else {
        session = try XPCSession(xpcService: serviceName, options: .inactive)
        let test = Mirror(reflecting: session)
        for case let (label?, value) in test.children {
            if label == "_session" {
                print("HIT")
                "anchor apple".utf8CString.withUnsafeBufferPointer { x in
                    _ = xpc_session_set_peer_code_signing_requirement(
                        value,
                        x.baseAddress!
                    )
                }
            }
        }
//        try session.activate()
        //        }
        if warmup {
            Task { [self] in
                _ = try? await send()
            }
        }
    }

    public func send(_ message: some Encodable = Data()) async throws -> ResponseType {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try session.send(message) { result in
                    switch result {
                    case .success(let message):
                        if let result = try? message.decode(as: ResponseType.self) {
                            continuation.resume(returning: result)
                        } else if let error = try? message.decode(as: ErrorType.self) {
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

    public func complete() {
        session.cancel(reason: "Done")
    }

}

public struct UnknownMessageError: Error, Codable {}
