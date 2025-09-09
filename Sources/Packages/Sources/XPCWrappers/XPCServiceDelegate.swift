import Foundation

public final class XPCServiceDelegate: NSObject, NSXPCListenerDelegate {

    private let exportedObject: ErasedXPCProtocol

    public init<XPCProtocolType: XPCProtocol>(exportedObject: XPCProtocolType) {
        self.exportedObject = ErasedXPCProtocol(exportedObject)
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: (any _XPCProtocol).self)
        let exportedObject = exportedObject
        newConnection.exportedObject = exportedObject
        newConnection.setCodeSigningRequirement("anchor apple generic and certificate leaf[subject.OU] = Z72PRUAWF6")
        newConnection.resume()
        return true
    }
}

@objc private final class ErasedXPCProtocol: NSObject, _XPCProtocol {

    let _process: @Sendable (Data, @Sendable @escaping (Data?, (any Error)?) -> Void) -> Void

    public init<XPCProtocolType: XPCProtocol>(_ exportedObject: XPCProtocolType) {
        _process = { data, reply in
            Task { [reply] in
                do {
                    let decoded = try JSONDecoder().decode(XPCProtocolType.Input.self, from: data)
                    let result = try await exportedObject.process(decoded)
                    let encoded = try JSONEncoder().encode(result)
                    reply(encoded, nil)
                } catch {
                    if let error = error as? Codable & Error {
                        reply(nil, NSError(error))
                    } else {
                        reply(nil, error)
                    }
                }
            }
        }
    }

    func process(_ data: Data, with reply: @Sendable @escaping (Data?, (any Error)?) -> Void) {
        _process(data, reply)
    }


}

extension NSError {

    private enum Constants {
        static let domain = "com.maxgoedjen.secretive.xpcwrappers"
        static let code = -1
        static let dataKey = "underlying"
    }

    @nonobjc convenience init<ErrorType: Codable & Error>(_ error: ErrorType) {
        let encoded = try? JSONEncoder().encode(error)
        self.init(domain: Constants.domain, code: Constants.code, userInfo: [Constants.dataKey: encoded as Any])
    }

    @nonobjc public func underlying<ErrorType: Codable & Error>(as errorType: ErrorType.Type) -> ErrorType? {
        guard domain == Constants.domain && code == Constants.code, let data = userInfo[Constants.dataKey] as? Data else { return nil }
        return try? JSONDecoder().decode(ErrorType.self, from: data)
    }

}

