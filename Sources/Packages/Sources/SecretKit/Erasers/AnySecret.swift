import Foundation

/// Type eraser for Secret.
public struct AnySecret: Secret, @unchecked Sendable {

    public let base: Any
    private let hashable: AnyHashable
    private let _id: () -> AnyHashable
    private let _name: () -> String
    private let _algorithm: () -> Algorithm
    private let _keySize: () -> Int
    private let _requiresAuthentication: () -> Bool
    private let _publicKey: () -> Data

    public init<T>(_ secret: T) where T: Secret {
        if let secret = secret as? AnySecret {
            base = secret.base
            hashable = secret.hashable
            _id = secret._id
            _name = secret._name
            _algorithm = secret._algorithm
            _keySize = secret._keySize
            _requiresAuthentication = secret._requiresAuthentication
            _publicKey = secret._publicKey
        } else {
            base = secret as Any
            self.hashable = secret
            _id = { secret.id as AnyHashable }
            _name = { secret.name }
            _algorithm = { secret.algorithm }
            _keySize = { secret.keySize }
            _requiresAuthentication = { secret.requiresAuthentication }
            _publicKey = { secret.publicKey }
        }
    }

    public var id: AnyHashable {
        _id()
    }

    public var name: String {
        _name()
    }

    public var algorithm: Algorithm {
        _algorithm()
    }

    public var keySize: Int {
        _keySize()
    }

    public var requiresAuthentication: Bool {
        _requiresAuthentication()
    }

    public var publicKey: Data {
        _publicKey()
    }

    public static func == (lhs: AnySecret, rhs: AnySecret) -> Bool {
        lhs.hashable == rhs.hashable
    }

    public func hash(into hasher: inout Hasher) {
        hashable.hash(into: &hasher)
    }

}

