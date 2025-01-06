import Foundation
import Observation
import Synchronization
import Backports

/// A "Store Store," which holds a list of type-erased stores.
@Observable public final class SecretStoreList: Sendable {

    /// The Stores managed by the SecretStoreList.
    public var stores: [AnySecretStore] {
        __stores.withLock { $0 }
    }
    private let __stores: _Mutex<[AnySecretStore]> = .init([])
    
    /// A modifiable store, if one is available.
    public var modifiableStore: AnySecretStoreModifiable? {
        __modifiableStore.withLock { $0 }
    }
    private let __modifiableStore: _Mutex<AnySecretStoreModifiable?> = .init(nil)

    /// Initializes a SecretStoreList.
    public init() {
    }

    /// Adds a non-type-erased SecretStore to the list.
    public func add<SecretStoreType: SecretStore>(store: SecretStoreType) {
        __stores.withLock {
            $0.append(AnySecretStore(store))
        }
    }

    /// Adds a non-type-erased modifiable SecretStore.
    public func add<SecretStoreType: SecretStoreModifiable>(store: SecretStoreType) {
        let modifiable = AnySecretStoreModifiable(modifiable: store)
        __modifiableStore.withLock {
            $0 = modifiable
        }
        __stores.withLock {
            $0.append(modifiable)
        }
    }

    /// A boolean describing whether there are any Stores available.
    public var anyAvailable: Bool {
        __stores.withLock {
            $0.reduce(false, { $0 || $1.isAvailable })
        }
    }

    public var allSecrets: [AnySecret] {
        __stores.withLock {
            $0.flatMap(\.secrets)
        }
    }

}
