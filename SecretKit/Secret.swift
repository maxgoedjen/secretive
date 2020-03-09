public protocol Secret: Identifiable, Hashable {

    var name: String { get }
    var algorithm: Algorithm { get }
    var keySize: Int { get }
    var publicKey: Data { get }

}

public enum Algorithm {
    case ellipticCurve, rsa
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
}
