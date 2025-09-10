import Foundation

/// Type eraser for Secret.
public struct AnySecret: Secret, @unchecked Sendable {

    public let base: any Secret
    private let _id: () -> AnyHashable
    private let _name: () -> String
    private let _publicKey: () -> Data
    private let _attributes: () -> Attributes
    private let _eq: (AnySecret) -> Bool

    public init<T>(_ secret: T) where T: Secret {
        if let secret = secret as? AnySecret {
            base = secret.base
            _id = secret._id
            _name = secret._name
            _publicKey = secret._publicKey
            _attributes = secret._attributes
            _eq = secret._eq
        } else {
            base = secret
            _id = { secret.id as AnyHashable }
            _name = { secret.name }
            _publicKey = { secret.publicKey }
            _attributes = { secret.attributes }
            _eq = { secret == $0.base as? T }
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
        lhs._eq(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

}

