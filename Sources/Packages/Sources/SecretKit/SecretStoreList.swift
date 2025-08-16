import Foundation
import Observation

/// A "Store Store," which holds a list of type-erased stores.
@Observable @MainActor public final class SecretStoreList: Sendable {

    /// The Stores managed by the SecretStoreList.
    public var stores: [AnySecretStore] = []
    /// A modifiable store, if one is available.
    public var modifiableStore: AnySecretStoreModifiable? = nil

    /// Initializes a SecretStoreList.
    public nonisolated init() {
    }

    /// Adds a non-type-erased SecretStore to the list.
    public func add<SecretStoreType: SecretStore>(store: SecretStoreType) {
        stores.append(AnySecretStore(store))
    }

    /// Adds a non-type-erased modifiable SecretStore.
    public func add<SecretStoreType: SecretStoreModifiable>(store: SecretStoreType) {
        let modifiable = AnySecretStoreModifiable(modifiable: store)
        if modifiableStore == nil {
            modifiableStore = modifiable
        }
        stores.append(modifiable)
    }

    /// A boolean describing whether there are any Stores available.
    public var anyAvailable: Bool {
        stores.contains(where: \.isAvailable)
    }

    public var allSecrets: [AnySecret] {
        stores.flatMap(\.secrets)
    }

}
