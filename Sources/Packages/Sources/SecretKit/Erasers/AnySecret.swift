import Foundation

/// Type eraser for Secret.
public struct AnySecret: Secret, @unchecked Sendable {

    let base: Any
    private let hashable: AnyHashable
    private let _id: () -> AnyHashable
    private let _name: () -> String
    private let _publicKey: () -> Data
    private let _attributes: () -> Attributes

    public init<T>(_ secret: T) where T: Secret {
        if let secret = secret as? AnySecret {
            base = secret.base
            hashable = secret.hashable
            _id = secret._id
            _name = secret._name
            _publicKey = secret._publicKey
            _attributes = secret._attributes
        } else {
            base = secret as Any
            self.hashable = secret
            _id = { secret.id as AnyHashable }
            _name = { secret.name }
            _publicKey = { secret.publicKey }
            _attributes = { secret.attributes }
        }
    }

    public var id: AnyHashable {
        _id()
    }

    public var name: String {
        _name()
    }

    public var publicKey: Data {
        _publicKey()
    }
    
    public var attributes: Attributes {
        _attributes()
    }

    public static func == (lhs: AnySecret, rhs: AnySecret) -> Bool {
        lhs.hashable == rhs.hashable
    }

    public func hash(into hasher: inout Hasher) {
        hashable.hash(into: &hasher)
    }

}

