import Foundation

/// Serializes signing operations for protected keys to prevent LAContext conflicts.
/// macOS only allows one biometric authentication prompt at a time, so concurrent
/// requests for protected Secure Enclave keys must be queued.
actor SigningSerializer {
    private var isProcessing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func serialize<T: Sendable>(operation: @escaping @Sendable () async throws -> T) async throws -> T {
        // If someone is already processing, wait in line
        if isProcessing {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isProcessing = true

        defer {
            if let next = waiters.first {
                waiters.removeFirst()
                next.resume()
            } else {
                isProcessing = false
            }
        }

        return try await operation()
    }
}
