import Foundation

public struct Attributes: Sendable, Codable, Hashable {
    
    /// The type of key involved.
    public let keyType: KeyType

    /// The authentication requirements for the key. This is simply a description of the option recorded at creation – modifying it doers not modify the key's authentication requirements.
    public let authentication: AuthenticationRequirement

    /// The authentication restrictions for the key.
    public var restrictions: Restrictions?

    /// The string appended to the end of the SSH Public Key.
    /// If nil, a default value will be used.
    public var publicKeyAttribution: String?

    public init(
        keyType: KeyType,
        authentication: AuthenticationRequirement,
        restrictions: Restrictions?,
        publicKeyAttribution: String? = nil
    ) {
        self.keyType = keyType
        self.authentication = authentication
        self.restrictions = restrictions
        self.publicKeyAttribution = publicKeyAttribution
    }

    public struct UnsupportedOptionError: Error {
        package init() {}
    }
    
}

/// The option specified
public enum AuthenticationRequirement: String, Hashable, Sendable, Codable, Identifiable {

    /// Authentication is not required for usage.
    case notRequired

    /// The user needs to authenticate, using either a biometric option, a connected authorized watch, or password entry..
    case presenceRequired

    /// ONLY the current set of biometric data, as matching at time of creation, is accepted.
    /// - Warning: This is a dangerous option prone to data loss. The user should be warned before configuring this key that if they modify their enrolled biometry INCLUDING by simply adding a new entry (ie, adding another fingeprting), the key will no longer be able to be accessed. This cannot be overridden with a password.
    case biometryCurrent

    /// The authentication requirement was not recorded at creation, and is unknown.
    case unknown

    /// Whether or not the key is known to require authentication.
    public var required: Bool {
        self == .presenceRequired || self == .biometryCurrent
    }

    public var id: AuthenticationRequirement {
        self
    }
}

/// The restrictions for the key.
public struct Restrictions: Hashable, Sendable, Codable, Identifiable {

    public enum AllowedDomains: Hashable, Sendable, Codable {
        case all
        case specific([String])

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .all:
                break
            case .specific(let values):
                values.hash(into: &hasher)
            }
        }

    }

    public enum AllowedProvenancePaths: Hashable, Sendable, Codable, Identifiable {
        case all
        case specific([String])

        public var id: Int {
            hashValue
        }
        
    }

    public var allowForwarding: Bool
    public var allowSigning: Bool
    public var allowConnections: Bool
    public var allowedDomains: AllowedDomains
    public var allowedProvenancePaths: AllowedProvenancePaths

    public var id: Restrictions {
        self
    }

//    public static let `default` = Restrictions(allowForwarding: true, allowSigning: true, allowConnections: true, allowedDomains: .all, allowedProvenancePaths: .all)
    public static let `default` = Restrictions(allowForwarding: true, allowSigning: true, allowConnections: true, allowedDomains: .specific(["example.com"]), allowedProvenancePaths: .all)

}
