import Foundation

/// Manages access to Secrets, and performs signature operations on data using those Secrets.
public protocol SecretStore<SecretType>: Identifiable, Sendable {

    associatedtype SecretType: Secret

    /// A boolean indicating whether or not the store is available.
    @MainActor var isAvailable: Bool { get }
    /// A unique identifier for the store.
    var id: UUID { get }
    /// A user-facing name for the store.
    @MainActor var name: String { get }
    /// The secrets the store manages.
    @MainActor var secrets: [SecretType] { get }

    /// Signs a data payload with a specified Secret.
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - secret: The ``Secret`` to sign with.
    ///   - provenance: A ``SigningRequestProvenance`` describing where the request came from.
    /// - Returns: The signed data.
    func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) async throws -> Data

    /// Checks to see if there is currently a valid persisted authentication for a given secret.
    /// - Parameters:
    ///   - secret: The ``Secret`` to check if there is a persisted authentication for.
    /// - Returns: A persisted authentication context, if a valid one exists.
    func existingPersistedAuthenticationContext(secret: SecretType) async -> PersistedAuthenticationContext?

    /// Persists user authorization for access to a secret.
    /// - Parameters:
    ///   - secret: The ``Secret`` to persist the authorization for.
    ///   - duration: The duration that the authorization should persist for.
    ///  - Note: This is used for temporarily unlocking access to a secret which would otherwise require authentication every single use. This is useful for situations where the user anticipates several rapid accesses to a authorization-guarded secret.
    func persistAuthentication(secret: SecretType, forDuration duration: TimeInterval) async throws

    /// Requests that the store reload secrets from any backing store, if neccessary.
    func reloadSecrets() async

}

/// A SecretStore that the Secretive admin app can modify.
public protocol SecretStoreModifiable<SecretType>: SecretStore {

    /// Creates a new ``Secret`` in the store.
    /// - Parameters:
    ///   - name: The user-facing name for the ``Secret``.
    ///   - attributes: A struct describing the options for creating the key.'
    @discardableResult
    func create(name: String, attributes: Attributes) async throws -> SecretType

    /// Deletes a Secret in the store.
    /// - Parameters:
    ///   - secret: The ``Secret`` to delete.
    func delete(secret: SecretType) async throws

    /// Updates the name of a Secret in the store.
    /// - Parameters:
    ///   - secret: The ``Secret`` to update.
    ///   - name: The new name for the Secret.
    ///   - attributes: The new attributes for the secret.
    func update(secret: SecretType, name: String, attributes: Attributes) async throws

    var supportedKeyTypes: KeyAvailability { get }

}

public struct KeyAvailability: Sendable {

    public let available: [KeyType]
    public let unavailable: [UnavailableKeyType]

    public init(available: [KeyType], unavailable: [UnavailableKeyType]) {
        self.available = available
        self.unavailable = unavailable
    }

    public struct UnavailableKeyType: Sendable {
        public let keyType: KeyType
        public let reason: LocalizedStringResource

        public init(keyType: KeyType, reason: LocalizedStringResource) {
            self.keyType = keyType
            self.reason = reason
        }
    }

}


extension NSNotification.Name {

    // Distributed notification that keys were modified out of process (ie, that the management tool added/removed secrets)
    public static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")
    // Internal notification that keys were reloaded from the backing store.
    public static let secretStoreReloaded = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.reloaded")

}
