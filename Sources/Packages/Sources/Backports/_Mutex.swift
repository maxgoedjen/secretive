import Foundation

#if canImport(Synchronization)
import Synchronization
public typealias _Mutex = Mutex
#else

import os

public final class _Mutex<Value: ~Copyable>: @unchecked Sendable {
    
    private var value: Value
    private var lock = OSAllocatedUnfairLock()
    
    public init(_ value: consuming sending Value) {
        self.value = value
    }
    
    public borrowing func withLock<Result, E>(_ body: (inout sending Value) throws(E) -> sending Result) throws(E) -> sending Result where E : Error, Result : ~Copyable {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try body(&value)
    }

    
}

#endif
