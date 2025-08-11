import Foundation
import Observation
import os
import Common

/// A "Store Store," which holds a list of type-erased stores.
@Observable public final class SecretStoreList: Sendable {

    /// The Stores managed by the SecretStoreList.
    public var stores: [AnySecretStore] {
        __stores.lockedValue
    }
    private let __stores: OSAllocatedUnfairLock<[AnySecretStore]> = .init(uncheckedState: [])
    
    /// A modifiable store, if one is available.
    public var modifiableStore: AnySecretStoreModifiable? {
        __modifiableStore.withLock { $0 }
    }
    private let __modifiableStore: OSAllocatedUnfairLock<AnySecretStoreModifiable?> = .init(uncheckedState: nil)

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
        __modifiableStore.lockedValue = modifiable
        __stores.withLock {
            $0.append(modifiable)
        }
    }

    /// A boolean describing whether there are any Stores available.
    public var anyAvailable: Bool {
        __stores.lockedValue.contains(where: \.isAvailable)
    }

    public var allSecrets: [AnySecret] {
        __stores.lockedValue.flatMap(\.secrets)
    }

}
