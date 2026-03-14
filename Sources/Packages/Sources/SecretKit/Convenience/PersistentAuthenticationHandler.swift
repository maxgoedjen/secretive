import LocalAuthentication

/// A context describing a persisted authentication.
package struct PersistentAuthenticationContext<SecretType: Secret>: PersistedAuthenticationContext {

    /// The Secret to persist authentication for.
    let secret: SecretType
    /// The LAContext used to authorize the persistent context.
    package nonisolated(unsafe) let context: LAContext
    /// An expiration date for the context.
    /// - Note -  Monotonic time instead of Date() to prevent people setting the clock back.
    let monotonicExpiration: UInt64

    /// Initializes a context.
    /// - Parameters:
    ///   - secret: The Secret to persist authentication for.
    ///   - context: The LAContext used to authorize the persistent context.
    ///   - duration: The duration of the authorization context, in seconds.
    init(secret: SecretType, context: LAContext, duration: TimeInterval) {
        self.secret = secret
        unsafe self.context = context
        let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
        self.monotonicExpiration = clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds)
    }

    /// A boolean describing whether or not the context is still valid.
    package var valid: Bool {
        clock_gettime_nsec_np(CLOCK_MONOTONIC) < monotonicExpiration
    }

    package var expiration: Date {
        let remainingNanoseconds = monotonicExpiration - clock_gettime_nsec_np(CLOCK_MONOTONIC)
        let remainingInSeconds = Measurement(value: Double(remainingNanoseconds), unit: UnitDuration.nanoseconds).converted(to: .seconds).value
        return Date(timeIntervalSinceNow: remainingInSeconds)
    }
}

struct ScopedPersistentAuthenticationContext<SecretType: Secret>: Hashable {
    let provenance: SigningRequestProvenance
    let secret: SecretType
}

package actor PersistentAuthenticationHandler<SecretType: Secret>: Sendable {

    private var unscopedPersistedAuthenticationContexts: [SecretType: PersistentAuthenticationContext<SecretType>] = [:]
    private var scopedPersistedAuthenticationContexts: [ScopedPersistentAuthenticationContext<SecretType>: PersistentAuthenticationContext<SecretType>] = [:]

    package init() {
    }

    package func existingPersistedAuthenticationContext(secret: SecretType, provenance: SigningRequestProvenance) -> PersistentAuthenticationContext<SecretType>? {
        if let unscopedPersistence = unscopedPersistedAuthenticationContexts[secret], unscopedPersistence.valid {
            return unscopedPersistence
        }
        if let scopedPersistence = scopedPersistedAuthenticationContexts[.init(provenance: provenance, secret: secret)], scopedPersistence.valid {
            return scopedPersistence
        }
        return nil
    }

    package func persistAuthentication(secret: SecretType, forDuration duration: TimeInterval) async throws {
        let newContext = LAContext()
        newContext.touchIDAuthenticationAllowableReuseDuration = duration
        newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.hour, .minute, .day]


        let durationString = formatter.string(from: duration)!
        newContext.localizedReason = String(localized: .authContextPersistForDuration(secretName: secret.name, duration: durationString))
        let success = try await newContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: newContext.localizedReason)
        guard success else { return }
        let context = PersistentAuthenticationContext(secret: secret, context: newContext, duration: duration)
        unscopedPersistedAuthenticationContexts[secret] = context
    }

    package func persistAuthentication(secret: SecretType, provenance: SigningRequestProvenance) async throws {
        let newContext = LAContext()

        // FIXME: TEMPORARY
        let duration: TimeInterval = 10000
        newContext.touchIDAuthenticationAllowableReuseDuration = duration
        newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)

        newContext.localizedReason = "Batch requests"
        let success = try await newContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: newContext.localizedReason)
        guard success else { return }
        let context = PersistentAuthenticationContext(secret: secret, context: newContext, duration: duration)
        scopedPersistedAuthenticationContexts[.init(provenance: provenance, secret: secret)] = context
    }

}

