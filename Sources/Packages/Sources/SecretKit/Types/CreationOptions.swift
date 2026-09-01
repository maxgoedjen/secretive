import Foundation

public struct Attributes: Sendable, Codable, Hashable {
    
    /// The type of key involved.
    public let keyType: KeyType

    /// The authentication requirements for the key. This is simply a description of the option recorded at creation – modifying it doers not modify the key's authentication requirements.
    public let authentication: AuthenticationRequirement
    
    /// Whether the key remains usable while the Mac is locked after its first unlock.
    public let usableWhileLocked: Bool
    
    /// The string appended to the end of the SSH Public Key.
    /// If nil, a default value will be used.
    public var publicKeyAttribution: String?

    public init(
        keyType: KeyType,
        authentication: AuthenticationRequirement,
        usableWhileLocked: Bool = false,
        publicKeyAttribution: String? = nil
    ) {
        self.keyType = keyType
        self.authentication = authentication
        self.usableWhileLocked = usableWhileLocked
        self.publicKeyAttribution = publicKeyAttribution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyType = try container.decode(KeyType.self, forKey: .keyType)
        authentication = try container.decode(AuthenticationRequirement.self, forKey: .authentication)
        usableWhileLocked = try container.decodeIfPresent(Bool.self, forKey: .usableWhileLocked) ?? false
        publicKeyAttribution = try container.decodeIfPresent(String.self, forKey: .publicKeyAttribution)
    }

    private enum CodingKeys: CodingKey {
        case keyType
        case authentication
        case usableWhileLocked
        case publicKeyAttribution
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
