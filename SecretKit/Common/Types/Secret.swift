public protocol Secret: Identifiable, Hashable {

    var name: String { get }
    var algorithm: Algorithm { get }
    var keySize: Int { get }
    var publicKey: Data { get }

}

public enum Algorithm: Hashable {
    case ellipticCurve
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
