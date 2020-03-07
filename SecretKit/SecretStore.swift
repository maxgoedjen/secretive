import Combine

public protocol SecretStore: ObservableObject {

    associatedtype SecretType: Secret
    var isAvailable: Bool { get }
    var name: String { get }
    var secrets: [SecretType] { get }

    func sign(data: Data, with secret: SecretType) throws -> Data
    func delete(secret: SecretType) throws

}

extension NSNotification.Name {

    static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")

}

public class AnySecretStore: SecretStore {

    fileprivate let base: Any
    fileprivate let _isAvailable: () -> Bool
    fileprivate let _name: () -> String
    fileprivate let _secrets: () -> [AnySecret]
    fileprivate let _sign: (Data, AnySecret) throws -> Data
    fileprivate let _delete: (AnySecret) throws -> Void

    public init<T>(_ secretStore: T) where T: SecretStore {
        base = secretStore
        _isAvailable = { secretStore.isAvailable }
        _name = { secretStore.name }
        _secrets = { secretStore.secrets.map { AnySecret($0) } }
        _sign = { try secretStore.sign(data: $0, with: $1 as! T.SecretType) }
        _delete = { try secretStore.delete(secret: $0 as! T.SecretType) }
    }
    
    public var isAvailable: Bool {
        return _isAvailable()
    }

    public var name: String {
        return _name()
    }

    public var secrets: [AnySecret] {
        return _secrets()
    }

    public func sign(data: Data, with secret: AnySecret) throws -> Data {
        try _sign(data, secret)
    }

    public func delete(secret: AnySecret) throws {
        try _delete(secret)
    }

}


