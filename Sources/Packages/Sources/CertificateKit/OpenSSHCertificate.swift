import Foundation
import Formatters

public struct OpenSSHCertificate: Sendable, Codable, Equatable, Hashable, CustomDebugStringConvertible {

    public var type: CertificateType
    public var name: String
    public var data: Data

    public var publicKey: PublicKey
    public var principals: [String]
    public var keyID: String
    public var serial: UInt64
    public var validityRange: Range<Date>?
    public var criticalOptions: [String]
    public var extensions: [String]
    public var signingKey: PublicKey

    public init(
        type: OpenSSHCertificate.CertificateType,
        name: String,
        data: Data,
        publicKey: PublicKey,
        principals: [String],
        keyID: String,
        serial: UInt64,
        validityRange: Range<Date>? = nil,
        criticalOptions: [String],
        extensions: [String],
        signingKey: PublicKey,
    ) {
        self.type = type
        self.name = name
        self.data = data
        self.publicKey = publicKey
        self.principals = principals
        self.keyID = keyID
        self.serial = serial
        self.validityRange = validityRange
        self.criticalOptions = criticalOptions
        self.extensions = extensions
        self.signingKey = signingKey
    }

    public var debugDescription: String {
        "OpenSSH Certificate \(name, default: "Unnamed"): \(data.formatted(.hex()))"
    }

}

extension OpenSSHCertificate {

    public enum CertificateType: String, Sendable, Codable {
        case ecdsa256 = "ecdsa-sha2-nistp256-cert-v01@openssh.com"
        case ecdsa384 = "ecdsa-sha2-nistp384-cert-v01@openssh.com"
        case nistp521 = "ecdsa-sha2-nistp521-cert-v01@openssh.com"

        public var keyIdentifier: String {
            rawValue.replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
        }

    }

}

extension OpenSSHCertificate {

    public struct PublicKey: Hashable, Sendable, Codable {

        public let keyType: String
        public let curveName: String
        public let data: Data

        public init(keyType: String, curveName: String, data: Data) {
            self.keyType = keyType
            self.curveName = curveName
            self.data = data
        }

    }

}
