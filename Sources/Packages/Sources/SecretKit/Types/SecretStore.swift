import Foundation
import Combine

/// Manages access to Secrets, and performs signature operations on data using those Secrets.
public protocol SecretStore: ObservableObject, Identifiable {

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
    /// - Returns: A ``SignedData`` object, containing the signature and metadata about the signature process.
    func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> SignedData

    /// Persists user authorization for access to a secret.
    /// - Parameters:
    ///   - secret: The ``Secret`` to persist the authorization for.
    ///   - duration: The duration that the authorization should persist for.
    ///  - Note: This is used for temporarily unlocking access to a secret which would otherwise require authentication every single use. This is useful for situations where the user anticipates several rapid accesses to a authorization-guarded secret.
    func persistAuthentication(secret: SecretType, forDuration duration: TimeInterval) throws

}

/// A SecretStore that the Secretive admin app can modify.
public protocol SecretStoreModifiable: SecretStore {

    /// Creates a new ``Secret`` in the store.
    /// - Parameters:
    ///   - name: The user-facing name for the ``Secret``.
    ///   - requiresAuthentication: A boolean indicating whether or not the user will be required to authenticate before performing signature operations with the secret.
    func create(name: String, requiresAuthentication: Bool) throws

    /// Deletes a Secret in the store.
    /// - Parameters:
    ///   - secret: The ``Secret`` to delete.
    func delete(secret: SecretType) throws

    
    func update(secret: SecretType, name: String) throws

}

extension NSNotification.Name {

    public static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")

}
