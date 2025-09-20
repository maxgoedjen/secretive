import Foundation
import OSLog

public struct OpenSSHCertificate: Sendable, Codable, Equatable, Hashable, Identifiable, CustomDebugStringConvertible {

    public var id: Int { hashValue }
    public var type: CertificateType
    public let name: String?
    public let data: Data

    public var debugDescription: String {
        "OpenSSH Certificate \(name, default: "Unnamed"): \(data.formatted(.hex()))"
    }

}

extension OpenSSHCertificate {

    public enum CertificateType: String, Sendable, Codable {
        case ecdsa256 = "ecdsa-sha2-nistp256-cert-v01@openssh.com"
        case ecdsa384 = "ecdsa-sha2-nistp384-cert-v01@openssh.com"
        case nistp521 = "ecdsa-sha2-nistp521-cert-v01@openssh.com"

        var keyIdentifier: String {
            rawValue.replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
        }
    }

}

public protocol OpenSSHCertificateParserProtocol {
    func parse(data: Data) async throws -> OpenSSHCertificate
}

public struct OpenSSHCertificateParser: OpenSSHCertificateParserProtocol, Sendable {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive", category: "OpenSSHCertificateParser")

    public init() {
    }

    public func parse(data: Data) throws(OpenSSHCertificateError) -> OpenSSHCertificate {
        let string = String(decoding: data, as: UTF8.self)
        var elements = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
        guard elements.count >= 2 else {
            throw OpenSSHCertificateError.parsingFailed
        }
        let typeString = elements.removeFirst()
        guard let type = OpenSSHCertificate.CertificateType(rawValue: typeString) else { throw .unsupportedType }
        let encodedKey = elements.removeFirst()
        guard let decoded = Data(base64Encoded: encodedKey)  else {
            throw OpenSSHCertificateError.parsingFailed
        }
        let name = elements.first
        return OpenSSHCertificate(type: type, name: name, data: decoded)
    }

}

public enum OpenSSHCertificateError: Error, Codable {
    case unsupportedType
    case parsingFailed
}
