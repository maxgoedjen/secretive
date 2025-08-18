import Foundation

/// The base protocol for describing a Secret
public protocol Secret: Identifiable, Hashable, Sendable {

    /// A user-facing string identifying the Secret.
    var name: String { get }
    /// The public key data for the secret.
    var publicKey: Data { get }
    /// The attributes of the key.
    var attributes: Attributes { get }

}

public extension Secret {

    /// The algorithm and key size this secret uses.
    var keyType: KeyType {
        attributes.keyType
    }

    /// Whether the secret requires authentication before use.
    var authenticationRequirement: AuthenticationRequirement {
        attributes.authentication
    }
    /// An attribution string to apply to the generated public key.
    var publicKeyAttribution: String? {
        attributes.publicKeyAttribution
    }

}

/// The type of algorithm the Secret uses.
public struct KeyType: Hashable, Sendable, Codable, CustomStringConvertible {
    
    public enum Algorithm: Hashable, Sendable, Codable {
        case ecdsa
        case mldsa
        case rsa
    }

    public var algorithm: Algorithm
    public var size: Int
    
    public init(algorithm: Algorithm, size: Int) {
        self.algorithm = algorithm
        self.size = size
    }

    /// Initializes the Algorithm with a secAttr representation of an algorithm.
    /// - Parameter secAttr: the secAttr, represented as an NSNumber.
    public init?(secAttr: NSNumber, size: Int) {
        let secAttrString = secAttr.stringValue as CFString
        switch secAttrString {
        case kSecAttrKeyTypeEC:
            algorithm = .ecdsa
        case kSecAttrKeyTypeRSA:
            algorithm = .rsa
        default:
            return nil
        }
        self.size = size
    }
    
    public var secAttrKeyType: CFString? {
        switch algorithm {
        case .ecdsa:
            kSecAttrKeyTypeEC
        case .rsa:
            kSecAttrKeyTypeRSA
        default:
            nil
        }
    }
    
    public var description: String {
        "\(algorithm)-\(size)"
    }
}
