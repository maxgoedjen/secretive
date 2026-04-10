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
    func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance, context: AuthenticationContextProtocol) async throws -> Data

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
        public let reason: Reason

        public init(keyType: KeyType, reason: Reason) {
            self.keyType = keyType
            self.reason = reason
        }

        public enum Reason: Sendable {
            case macOSUpdateRequired
        }
    }

}


extension NSNotification.Name {

    // Distributed notification that keys were modified out of process (ie, that the management tool added/removed secrets)
    public static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")
    // Internal notification that keys were reloaded from the backing store.
    public static let secretStoreReloaded = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.reloaded")

}
