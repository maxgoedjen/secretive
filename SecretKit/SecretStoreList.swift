import Foundation
import Combine

public class SecretStoreList: ObservableObject {

    @Published public var stores: [AnySecretStore] = []
    @Published public var modifiableStore: AnySecretStoreModifiable?

    public init() {
    }

    public func add<SecretStoreType: SecretStore>(store: SecretStoreType) {
        stores.append(AnySecretStore(store))
    }

    public func add<SecretStoreType: SecretStoreModifiable>(store: SecretStoreType) {
        let modifiable = AnySecretStoreModifiable(modifiable: store)
        modifiableStore = modifiable
        stores.append(modifiable)
    }

}
