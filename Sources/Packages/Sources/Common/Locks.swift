import os

public extension OSAllocatedUnfairLock where State: Sendable {
    
    var lockedValue: State {
        get {
            withLock { $0 }
        }
        nonmutating set {
            withLock { $0 = newValue }
        }
    }

}
