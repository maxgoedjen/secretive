import Foundation
import CryptoKit
import Formatters

@dynamicMemberLookup
public struct Certificate: Sendable, Codable, Equatable, Hashable, Identifiable, CustomDebugStringConvertible {

    public var openSSHCertificate: OpenSSHCertificate
    public let rawData: Data

    public init(openSSHCertificate: OpenSSHCertificate, rawData: Data) {
        self.openSSHCertificate = openSSHCertificate
        self.rawData = rawData
    }

    public var id: String { Insecure.MD5.hash(data: rawData).formatted(.hex(separator: "")) }

    public var debugDescription: String { openSSHCertificate.debugDescription }

    public subscript<T>(dynamicMember keyPath: KeyPath<OpenSSHCertificate, T>) -> T {
        openSSHCertificate[keyPath: keyPath]
    }

}
