import Foundation
import Combine

/// A "Store Store," which holds a list of type-erased stores.
public class SecretStoreList: ObservableObject {

    /// The Stores managed by the SecretStoreList.
    @Published public var stores: [AnySecretStore] = []
    /// A modifiable store, if one is available.
    @Published public var modifiableStore: AnySecretStoreModifiable?
    private var sinks: [AnyCancellable] = []

    /// Initializes a SecretStoreList.
    public init() {
    }

    /// Adds a non-type-erased SecretStore to the list.
    public func add<SecretStoreType: SecretStore>(store: SecretStoreType) {
        addInternal(store: AnySecretStore(store))
    }

    /// Adds a non-type-erased modifiable SecretStore.
    public func add<SecretStoreType: SecretStoreModifiable>(store: SecretStoreType) {
        let modifiable = AnySecretStoreModifiable(modifiable: store)
        modifiableStore = modifiable
        addInternal(store: modifiable)
    }

    /// A boolean describing whether there are any Stores available.
    public var anyAvailable: Bool {
        stores.reduce(false, { $0 || $1.isAvailable })
    }

    public var allSecrets: [AnySecret] {
        stores.flatMap(\.secrets)
    }

}

extension SecretStoreList {

    private func addInternal(store: AnySecretStore) {
        stores.append(store)
        let sink = store.objectWillChange.sink {
            self.objectWillChange.send()
        }
        sinks.append(sink)
    }

}
