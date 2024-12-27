import Foundation
import Combine

/// Manages access to Secrets, and performs signature operations on data using those Secrets.
public protocol SecretStore: Identifiable, Sendable {

    associatedtype SecretType: Secret

    /// A boolean indicating whether or not the store is available.
    var isAvailable: Bool { get }
    /// A unique identifier for the store.
    var id: UUID { get }
    /// A user-facing name for the store.
    var name: String { get }
    /// The secrets the store manages.
    var secrets: [SecretType] { get }

    /// Signs a data payload with a specified Secret.
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - secret: The ``Secret`` to sign with.
    ///   - provenance: A ``SigningRequestProvenance`` describing where the request came from.
    /// - Returns: The signed data.
    func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) async throws -> Data

    /// Verifies that a signature is valid over a specified payload.
    /// - Parameters:
    ///   - signature: The signature over the data.
    ///   - data: The data to verify the signature of.
    ///   - secret: The secret whose signature to verify.
    /// - Returns: Whether the signature was verified.
    func verify(signature: Data, for data: Data, with secret: SecretType) async throws -> Bool

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
public protocol SecretStoreModifiable: SecretStore {

    /// Creates a new ``Secret`` in the store.
    /// - Parameters:
    ///   - name: The user-facing name for the ``Secret``.
    ///   - requiresAuthentication: A boolean indicating whether or not the user will be required to authenticate before performing signature operations with the secret.
    func create(name: String, requiresAuthentication: Bool) async throws

    /// Deletes a Secret in the store.
    /// - Parameters:
    ///   - secret: The ``Secret`` to delete.
    func delete(secret: SecretType) async throws

    /// Updates the name of a Secret in the store.
    /// - Parameters:
    ///   - secret: The ``Secret`` to update.
    ///   - name: The new name for the Secret.
    func update(secret: SecretType, name: String) async throws

}

extension NSNotification.Name {

    // Distributed notification that keys were modified out of process (ie, that the management tool added/removed secrets)
    public static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")
    // Internal notification that keys were reloaded from the backing store.
    public static let secretStoreReloaded = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.reloaded")

}
