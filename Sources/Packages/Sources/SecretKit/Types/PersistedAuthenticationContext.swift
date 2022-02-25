import Foundation

/// Protocol describing a persisted authentication context. This is an authorization that can be reused for multiple access to a secret that requires authentication for a specific period of time.
public protocol PersistedAuthenticationContext {
    /// Whether the context remains valid.
    var valid: Bool { get }
    /// The date at which the authorization expires and the context becomes invalid.
    var expiration: Date { get }
}
