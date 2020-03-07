public protocol Secret: Identifiable, Hashable {

    var name: String { get }
    var publicKey: Data { get }

}



public struct AnySecret: Secret {

    fileprivate let hashable: AnyHashable
    fileprivate let _id: () -> AnyHashable
    fileprivate let _name: () -> String
    fileprivate let _publicKey: () -> Data

    public init<T>(_ secret: T) where T: Secret {
        self.hashable = secret
        _id = { secret.id as AnyHashable }
        _name = { secret.name }
        _publicKey = { secret.publicKey }
    }

    public var id: AnyHashable {
        return _id()
    }

    public var name: String {
        return _name()
    }

    public var publicKey: Data {
        return _publicKey()
    }

    public static func == (lhs: AnySecret, rhs: AnySecret) -> Bool {
        lhs.hashable == rhs.hashable
    }

    public func hash(into hasher: inout Hasher) {
        hashable.hash(into: &hasher)
    }

}

