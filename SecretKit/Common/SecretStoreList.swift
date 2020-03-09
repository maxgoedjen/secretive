import Foundation
import Combine

public class SecretStoreList: ObservableObject {

    @Published public var stores: [AnySecretStore] = []
    @Published public var modifiableStore: AnySecretStoreModifiable?
    fileprivate var sinks: [AnyCancellable] = []

    public init() {
    }

    public func add<SecretStoreType: SecretStore>(store: SecretStoreType) {
        addInternal(store: AnySecretStore(store))
    }

    public func add<SecretStoreType: SecretStoreModifiable>(store: SecretStoreType) {
        let modifiable = AnySecretStoreModifiable(modifiable: store)
        modifiableStore = modifiable
        addInternal(store: modifiable)
    }

}

extension SecretStoreList {

    fileprivate func addInternal(store: AnySecretStore) {
        stores.append(store)
        let sink = store.objectWillChange.sink {
            self.objectWillChange.send()
        }
        sinks.append(sink)
    }

}
