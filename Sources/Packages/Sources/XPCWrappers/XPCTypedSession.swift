import Foundation

public struct XPCTypedSession<ResponseType: Codable & Sendable, ErrorType: Error & Codable>: ~Copyable {

    private let connection: NSXPCConnection
    private let proxy: _XPCProtocol

    public init(serviceName: String, warmup: Bool = false) async throws {
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: (any _XPCProtocol).self)
        #if !DEBUG
        connection.setCodeSigningRequirement("anchor apple generic and certificate leaf[subject.OU] = \"Z72PRUAWF6\"")
        #endif
        connection.resume()
        guard let proxy = connection.remoteObjectProxy as? _XPCProtocol else { fatalError() }
        self.connection = connection
        self.proxy = proxy
        if warmup {
            _ = try? await send()
        }
    }

    public func send(_ message: some Encodable = Data()) async throws -> ResponseType {
        let encoded = try JSONEncoder().encode(message)
        return try await withCheckedThrowingContinuation { continuation in
            let activeProxy = connection.remoteObjectProxyWithErrorHandler { error in
                continuation.resume(throwing: error)
            }
            guard let typedProxy = activeProxy as? _XPCProtocol else {
                continuation.resume(throwing: NoDataError())
                return
            }
            typedProxy.process(encoded) { data, error in
                do {
                    if let error {
                        throw error
                    }
                    guard let data else {
                        throw NoDataError()
                    }
                    let decoded = try JSONDecoder().decode(ResponseType.self, from: data)
                    continuation.resume(returning: decoded)
                } catch {
                    if let typed = (error as NSError).underlying(as: ErrorType.self) {
                        continuation.resume(throwing: typed)
                    } else {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }


    public func complete() {
        connection.invalidate()
    }

    public struct NoDataError: Error {}

}

