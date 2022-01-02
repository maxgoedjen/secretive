import Foundation

/// The base protocol for describing a Secret
public protocol Secret: Identifiable, Hashable {

    /// A user-facing string identifying the Secret.
    var name: String { get }
    /// The algorithm this secret uses.
    var algorithm: Algorithm { get }
    /// The key size for the secret.
    var keySize: Int { get }
    /// The public key data for the secret.
    var publicKey: Data { get }

}

/// The type of algorithm the Secret uses. Currently, only elliptic curve algorithms are supported.
public enum Algorithm: Hashable {

    case ellipticCurve

    /// Initializes the Algorithm with a secAttr representation of an algorithm.
    /// - Parameter secAttr: the secAttr, represented as an NSNumber.
    public init(secAttr: NSNumber) {
        let secAttrString = secAttr.stringValue as CFString
        switch secAttrString {
        case kSecAttrKeyTypeEC:
            self = .ellipticCurve
        default:
            fatalError()
        }
    }
}
