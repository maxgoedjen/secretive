import Foundation

/// Type eraser for Secret.
public struct AnySecret: Secret, @unchecked Sendable {

    let base: Any
    private let hashable: AnyHashable
    private let _id: () -> AnyHashable
    private let _name: () -> String
    private let _keyType: () -> KeyType
    private let _authenticationRequirement: () -> AuthenticationRequirement
    private let _publicKey: () -> Data
    private let _publicKeyAttribution: () -> String?

    public init<T>(_ secret: T) where T: Secret {
        if let secret = secret as? AnySecret {
            base = secret.base
            hashable = secret.hashable
            _id = secret._id
            _name = secret._name
            _keyType = secret._keyType
            _authenticationRequirement = secret._authenticationRequirement
            _publicKey = secret._publicKey
            _publicKeyAttribution = secret._publicKeyAttribution
        } else {
            base = secret as Any
            self.hashable = secret
            _id = { secret.id as AnyHashable }
            _name = { secret.name }
            _keyType = { secret.keyType }
            _authenticationRequirement = { secret.authenticationRequirement }
            _publicKey = { secret.publicKey }
            _publicKeyAttribution = { secret.publicKeyAttribution }
        }
    }

    public var id: AnyHashable {
        _id()
    }

    public var name: String {
        _name()
    }

    public var keyType: KeyType {
        _keyType()
    }


    public var authenticationRequirement: AuthenticationRequirement {
        _authenticationRequirement()
    }

    public var publicKey: Data {
        _publicKey()
    }
    
    public var publicKeyAttribution: String? {
        _publicKeyAttribution()
    }

    public static func == (lhs: AnySecret, rhs: AnySecret) -> Bool {
        lhs.hashable == rhs.hashable
    }

    public func hash(into hasher: inout Hasher) {
        hashable.hash(into: &hasher)
    }

}

