import Foundation
import Combine

/// Type eraser for SecretStore.
public class AnySecretStore: SecretStore, @unchecked Sendable {

    let base: any Sendable
    private let _isAvailable: @MainActor @Sendable () -> Bool
    private let _id: @Sendable () -> UUID
    private let _name: @MainActor @Sendable () -> String
    private let _secrets: @MainActor @Sendable () -> [AnySecret]
    private let _sign: @Sendable (Data, AnySecret, SigningRequestProvenance) async throws -> Data
    private let _verify: @Sendable (Data, Data, AnySecret) async throws -> Bool
    private let _existingPersistedAuthenticationContext: @Sendable (AnySecret) async -> PersistedAuthenticationContext?
    private let _persistAuthentication: @Sendable (AnySecret, TimeInterval) async throws -> Void
    private let _reloadSecrets: @Sendable () async -> Void

    public init<SecretStoreType>(_ secretStore: SecretStoreType) where SecretStoreType: SecretStore {
        base = secretStore
        _isAvailable = { secretStore.isAvailable }
        _name = { secretStore.name }
        _id = { secretStore.id }
        _secrets = { secretStore.secrets.map { AnySecret($0) } }
        _sign = { try await secretStore.sign(data: $0, with: $1.base as! SecretStoreType.SecretType, for: $2) }
        _verify = { try await secretStore.verify(signature: $0, for: $1, with: $2.base as! SecretStoreType.SecretType) }
        _existingPersistedAuthenticationContext = { await secretStore.existingPersistedAuthenticationContext(secret: $0.base as! SecretStoreType.SecretType) }
        _persistAuthentication = { try await secretStore.persistAuthentication(secret: $0.base as! SecretStoreType.SecretType, forDuration: $1) }
        _reloadSecrets = { await secretStore.reloadSecrets() }
    }

    @MainActor public var isAvailable: Bool {
        return _isAvailable()
    }

    public var id: UUID {
        return _id()
    }

    @MainActor public var name: String {
        return _name()
    }

    @MainActor public var secrets: [AnySecret] {
        return _secrets()
    }

    public func sign(data: Data, with secret: AnySecret, for provenance: SigningRequestProvenance) async throws -> Data {
        try await _sign(data, secret, provenance)
    }

    public func verify(signature: Data, for data: Data, with secret: AnySecret) async throws -> Bool {
        try await _verify(signature, data, secret)
    }

    public func existingPersistedAuthenticationContext(secret: AnySecret) async -> PersistedAuthenticationContext? {
        await _existingPersistedAuthenticationContext(secret)
    }

    public func persistAuthentication(secret: AnySecret, forDuration duration: TimeInterval) async throws {
        try await _persistAuthentication(secret, duration)
    }

    public func reloadSecrets() async {
        await _reloadSecrets()
    }

}

public final class AnySecretStoreModifiable: AnySecretStore, SecretStoreModifiable, @unchecked Sendable {

    private let _create: @Sendable (String, Attributes) async throws -> Void
    private let _delete: @Sendable (AnySecret) async throws -> Void
    private let _update: @Sendable (AnySecret, String, Attributes) async throws -> Void
    private let _supportedKeyTypes: @Sendable () -> [KeyType]

    public init<SecretStoreType>(modifiable secretStore: SecretStoreType) where SecretStoreType: SecretStoreModifiable {
        _create = { try await secretStore.create(name: $0, attributes: $1) }
        _delete = { try await secretStore.delete(secret: $0.base as! SecretStoreType.SecretType) }
        _update = { try await secretStore.update(secret: $0.base as! SecretStoreType.SecretType, name: $1, attributes: $2) }
        _supportedKeyTypes = { secretStore.supportedKeyTypes }
        super.init(secretStore)
    }

    public func create(name: String, attributes: Attributes) async throws {
        try await _create(name, attributes)
    }

    public func delete(secret: AnySecret) async throws {
        try await _delete(secret)
    }

    public func update(secret: AnySecret, name: String, attributes: Attributes) async throws {
        try await _update(secret, name, attributes)
    }

    public var supportedKeyTypes: [KeyType] {
        _supportedKeyTypes()
    }

}
