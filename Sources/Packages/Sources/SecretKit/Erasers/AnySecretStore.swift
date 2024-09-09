import Foundation
import Combine

/// Type eraser for SecretStore.
public class AnySecretStore: SecretStore, ObservableObject {

    let base: Any
    private let _isAvailable: () -> Bool
    private let _id: () -> UUID
    private let _name: () -> String
    private let _secrets: () -> [AnySecret]
    private let _sign: (Data, AnySecret, SigningRequestProvenance) throws -> Data
    private let _verify: (Data, Data, AnySecret) throws -> Bool
    private let _existingPersistedAuthenticationContext: (AnySecret) -> PersistedAuthenticationContext?
    private let _persistAuthentication: (AnySecret, TimeInterval) throws -> Void
    private let _reloadSecrets: () -> Void

    private var sink: AnyCancellable?

    public init<SecretStoreType>(_ secretStore: SecretStoreType) where SecretStoreType: SecretStore {
        base = secretStore
        _isAvailable = { secretStore.isAvailable }
        _name = { secretStore.name }
        _id = { secretStore.id }
        _secrets = { secretStore.secrets.map { AnySecret($0) } }
        _sign = { try secretStore.sign(data: $0, with: $1.base as! SecretStoreType.SecretType, for: $2) }
        _verify = { try secretStore.verify(signature: $0, for: $1, with: $2.base as! SecretStoreType.SecretType) }
        _existingPersistedAuthenticationContext = { secretStore.existingPersistedAuthenticationContext(secret: $0.base as! SecretStoreType.SecretType) }
        _persistAuthentication = { try secretStore.persistAuthentication(secret: $0.base as! SecretStoreType.SecretType, forDuration: $1) }
        _reloadSecrets = { secretStore.reloadSecrets() }
        sink = secretStore.objectWillChange
            .receive(on: DispatchQueue.main) // Ensure updates are received on the main thread
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    public var isAvailable: Bool {
        return _isAvailable()
    }

    public var id: UUID {
        return _id()
    }

    public var name: String {
        return _name()
    }

    public var secrets: [AnySecret] {
        return _secrets()
    }

    public func sign(data: Data, with secret: AnySecret, for provenance: SigningRequestProvenance) throws -> Data {
        try _sign(data, secret, provenance)
    }

    public func verify(signature: Data, for data: Data, with secret: AnySecret) throws -> Bool {
        try _verify(signature, data, secret)
    }

    public func existingPersistedAuthenticationContext(secret: AnySecret) -> PersistedAuthenticationContext? {
        _existingPersistedAuthenticationContext(secret)
    }

    public func persistAuthentication(secret: AnySecret, forDuration duration: TimeInterval) throws {
        try _persistAuthentication(secret, duration)
    }

    public func reloadSecrets() {
        _reloadSecrets()
    }

}

public final class AnySecretStoreModifiable: AnySecretStore, SecretStoreModifiable {

    private let _create: (String, Bool) throws -> Void
    private let _delete: (AnySecret) throws -> Void
    private let _update: (AnySecret, String) throws -> Void

    public init<SecretStoreType>(modifiable secretStore: SecretStoreType) where SecretStoreType: SecretStoreModifiable {
        _create = { try secretStore.create(name: $0, requiresAuthentication: $1) }
        _delete = { try secretStore.delete(secret: $0.base as! SecretStoreType.SecretType) }
        _update = { try secretStore.update(secret: $0.base as! SecretStoreType.SecretType, name: $1) }
        super.init(secretStore)
    }

    public func create(name: String, requiresAuthentication: Bool) throws {
        try _create(name, requiresAuthentication)
    }

    public func delete(secret: AnySecret) throws {
        try _delete(secret)
    }

    public func update(secret: AnySecret, name: String) throws {
        try _update(secret, name)
    }

}
