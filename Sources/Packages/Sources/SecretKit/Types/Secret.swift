import Foundation

/// The base protocol for describing a Secret
public protocol Secret: Identifiable, Hashable, Sendable {

    /// A user-facing string identifying the Secret.
    var name: String { get }
    /// The algorithm this secret uses.
    var algorithm: Algorithm { get }
    /// The key size for the secret.
    var keySize: Int { get }
    /// Whether the secret requires authentication before use.
    var requiresAuthentication: Bool { get }
    /// The public key data for the secret.
    var publicKey: Data { get }

}

/// The type of algorithm the Secret uses. Currently, only elliptic curve algorithms are supported.
public enum Algorithm: Hashable, Sendable {

    case ellipticCurve
    case rsa

    /// Initializes the Algorithm with a secAttr representation of an algorithm.
    /// - Parameter secAttr: the secAttr, represented as an NSNumber.
    public init(secAttr: NSNumber) {
        let secAttrString = secAttr.stringValue as CFString
        switch secAttrString {
        case kSecAttrKeyTypeEC:
            self = .ellipticCurve
        case kSecAttrKeyTypeRSA:
            self = .rsa
        default:
            fatalError()
        }
    }
    
    public var secAttrKeyType: CFString {
        switch self {
        case .ellipticCurve:
            return kSecAttrKeyTypeEC
        case .rsa:
            return kSecAttrKeyTypeRSA
        }
    }
}
