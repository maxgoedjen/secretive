import LocalAuthentication
import SecretKit

extension SecureEnclave {

    /// A context describing a persisted authentication.
    final class PersistentAuthenticationContext: PersistedAuthenticationContext {

        /// The Secret to persist authentication for.
        let secret: Secret
        /// The LAContext used to authorize the persistent context.
        nonisolated(unsafe) let context: LAContext
        /// An expiration date for the context.
        /// - Note -  Monotonic time instead of Date() to prevent people setting the clock back.
        let monotonicExpiration: UInt64

        /// Initializes a context.
        /// - Parameters:
        ///   - secret: The Secret to persist authentication for.
        ///   - context: The LAContext used to authorize the persistent context.
        ///   - duration: The duration of the authorization context, in seconds.
        init(secret: Secret, context: LAContext, duration: TimeInterval) {
            self.secret = secret
            unsafe self.context = context
            let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
            self.monotonicExpiration = clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds)
        }

        /// A boolean describing whether or not the context is still valid.
        var valid: Bool {
            clock_gettime_nsec_np(CLOCK_MONOTONIC) < monotonicExpiration
        }

        var expiration: Date {
            let remainingNanoseconds = monotonicExpiration - clock_gettime_nsec_np(CLOCK_MONOTONIC)
            let remainingInSeconds = Measurement(value: Double(remainingNanoseconds), unit: UnitDuration.nanoseconds).converted(to: .seconds).value
            return Date(timeIntervalSinceNow: remainingInSeconds)
        }
    }

    actor PersistentAuthenticationHandler: Sendable {

        private var persistedAuthenticationContexts: [Secret: PersistentAuthenticationContext] = [:]

        func existingPersistedAuthenticationContext(secret: Secret) -> PersistentAuthenticationContext? {
            guard let persisted = persistedAuthenticationContexts[secret], persisted.valid else { return nil }
            return persisted
        }

        func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) async throws {
            let newContext = LAContext()
            newContext.touchIDAuthenticationAllowableReuseDuration = duration
            newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .spellOut
            formatter.allowedUnits = [.hour, .minute, .day]

            if let durationString = formatter.string(from: duration) {
                newContext.localizedReason = String(localized: .authContextPersistForDuration(secretName: secret.name, duration: durationString))
            } else {
                newContext.localizedReason = String(localized: .authContextPersistForDurationUnknown(secretName: secret.name))
            }
            let success = try await newContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: newContext.localizedReason)
            guard success else { return }
            let context = PersistentAuthenticationContext(secret: secret, context: newContext, duration: duration)
            persistedAuthenticationContexts[secret] = context
        }

    }

}
