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
