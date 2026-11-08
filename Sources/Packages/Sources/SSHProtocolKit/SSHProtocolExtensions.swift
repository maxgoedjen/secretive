import Foundation

// Extensions, as defined in https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.agent

extension SSHAgent {

    public enum ProtocolExtension: CustomDebugStringConvertible, Codable, Sendable {
        case openSSH(OpenSSHExtension)
        case secretive(SecretiveExtension)
        case unknown(String)

        public var debugDescription: String {
            switch self {
            case let .openSSH(protocolExtension):
                protocolExtension.debugDescription
            case let .secretive(protocolExtension):
                protocolExtension.debugDescription
            case .unknown(let string):
                "Unknown (\(string))"
            }
        }

        public static var empty: ProtocolExtension {
            .unknown("empty")
        }

        private struct ProtocolExtensionParsingError: Error {}

    }

}

extension SSHAgent.ProtocolExtension {

    public enum OpenSSHExtension: CustomDebugStringConvertible, Codable, Sendable {
        case sessionBind(SessionBindContext)
        case unknown(String)

        public static var domain: String {
            "openssh.com"
        }

        public var name: String {
            switch self {
            case .sessionBind:
                "session-bind"
            case .unknown(let name):
                name
            }
        }

        public var debugDescription: String {
            "\(name)@\(OpenSSHExtension.domain)"
        }
    }

}

extension SSHAgent.ProtocolExtension.OpenSSHExtension {

    public struct SessionBindContext: Codable, Sendable {

        public let hostKey: Data
        public let sessionID: Data
        public let signature: Data
        public let forwarding: Bool

        public init(hostKey: Data, sessionID: Data, signature: Data, forwarding: Bool) {
            self.hostKey = hostKey
            self.sessionID = sessionID
            self.signature = signature
            self.forwarding = forwarding
        }

        public static let empty = SessionBindContext(hostKey: Data(), sessionID: Data(), signature: Data(), forwarding: false)

    }

}

extension SSHAgent.ProtocolExtension {

    public enum SecretiveExtension: CustomDebugStringConvertible, Codable, Sendable {
        case createKey(CreateKeyContext)
        case deleteKey(DeleteKeyContext)
        case renameKey(RenameKeyContext)
        case listKeys
        case listCerts
        case importCert(ImportCertContext)
        case deleteCert(DeleteCertContext)
        case unknown(String)

        public static var domain: String {
            "secretive.app"
        }

        public var name: String {
            switch self {
            case .createKey:
                "create-key"
            case .deleteKey:
                "delete-key"
            case .renameKey:
                "rename-key"
            case .listKeys:
                "list-keys"
            case .listCerts:
                "list-certs"
            case .importCert:
                "import-cert"
            case .deleteCert:
                "delete-cert"
            case .unknown(let name):
                name
            }
        }

        public var debugDescription: String {
            "\(name)@\(SecretiveExtension.domain)"
        }
    }

}

extension SSHAgent.ProtocolExtension.SecretiveExtension {

    public struct CreateKeyContext: Codable, Sendable {
        public let name: String
        public let keyType: String
        public let requireBiometrics: Bool

        public init(name: String, keyType: String, requireBiometrics: Bool) {
            self.name = name
            self.keyType = keyType
            self.requireBiometrics = requireBiometrics
        }

        public static let empty = CreateKeyContext(name: "", keyType: "ecdsa-256", requireBiometrics: true)
    }

    public struct DeleteKeyContext: Codable, Sendable {
        public let identifier: String

        public init(identifier: String) {
            self.identifier = identifier
        }

        public static let empty = DeleteKeyContext(identifier: "")
    }

    public struct RenameKeyContext: Codable, Sendable {
        public let identifier: String
        public let newName: String
        public let attribution: String?

        public init(identifier: String, newName: String, attribution: String? = nil) {
            self.identifier = identifier
            self.newName = newName
            self.attribution = attribution
        }

        public static let empty = RenameKeyContext(identifier: "", newName: "")
    }

    public struct ImportCertContext: Codable, Sendable {
        public let certificateData: Data
        public let nameOverride: String?

        public init(certificateData: Data, nameOverride: String? = nil) {
            self.certificateData = certificateData
            self.nameOverride = nameOverride
        }

        public static let empty = ImportCertContext(certificateData: Data())
    }

    public struct DeleteCertContext: Codable, Sendable {
        public let identifier: String

        public init(identifier: String) {
            self.identifier = identifier
        }

        public static let empty = DeleteCertContext(identifier: "")
    }

}

// MARK: - Shared CLI / Agent Transfer Models

public struct KeyListItem: Codable, Sendable, Hashable {
    public let store: String
    public let name: String
    public let algorithm: String
    public let authentication: String
    public let fingerprint_sha256: String
    public let fingerprint_md5: String
    public let public_key: String
    public let public_key_path: String

    public init(
        store: String,
        name: String,
        algorithm: String,
        authentication: String,
        fingerprint_sha256: String,
        fingerprint_md5: String,
        public_key: String,
        public_key_path: String
    ) {
        self.store = store
        self.name = name
        self.algorithm = algorithm
        self.authentication = authentication
        self.fingerprint_sha256 = fingerprint_sha256
        self.fingerprint_md5 = fingerprint_md5
        self.public_key = public_key
        self.public_key_path = public_key_path
    }
}

public struct CertListItem: Codable, Sendable, Hashable {
    public let name: String
    public let key_id: String
    public let serial: UInt64
    public let principals: [String]
    public let valid_until: String?

    public init(name: String, key_id: String, serial: UInt64, principals: [String], valid_until: String?) {
        self.name = name
        self.key_id = key_id
        self.serial = serial
        self.principals = principals
        self.valid_until = valid_until
    }
}
