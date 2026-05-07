import Foundation
import CryptoKit

public struct HexDataStyle<SequenceType: Sequence>: Hashable, Codable {

    let separator: String

    public init(separator: String) {
        self.separator = separator
    }

}

extension HexDataStyle: FormatStyle where SequenceType.Element == UInt8 {

    public func format(_ value: SequenceType) -> String {
        value
            .compactMap { ("0" + String($0, radix: 16, uppercase: false)).suffix(2) }
            .joined(separator: separator)
    }

}

extension FormatStyle where Self == HexDataStyle<Data> {

    public static func hex(separator: String = "") -> HexDataStyle<Data> {
        HexDataStyle(separator: separator)
    }

}

extension FormatStyle where Self == HexDataStyle<Insecure.MD5Digest> {

    public static func hex(separator: String = ":") -> HexDataStyle<Insecure.MD5Digest> {
        HexDataStyle(separator: separator)
    }

}

public struct Base64DataStyle<SequenceType: Sequence>: Hashable, Codable {

    private let stripPadding: Bool

    public init(stripPadding: Bool) {
        self.stripPadding = stripPadding
    }

}

extension Base64DataStyle: FormatStyle where SequenceType.Element == UInt8 {

    public func format(_ value: SequenceType) -> String {
        let base64 = Data(value).base64EncodedString()
        let paddingRange = base64.index(base64.endIndex, offsetBy: -2)..<base64.endIndex
        return base64.replacingOccurrences(of: "=", with: "", range: paddingRange)
    }

}

extension FormatStyle where Self == Base64DataStyle<Data> {

    public static func base64(stripPadding: Bool) -> Base64DataStyle<Data> {
        Base64DataStyle(stripPadding: stripPadding)
    }

}

extension FormatStyle where Self == Base64DataStyle<SHA256.Digest> {

    public static func base64(stripPadding: Bool) -> Base64DataStyle<SHA256.Digest> {
        Base64DataStyle(stripPadding: stripPadding)
    }

}
