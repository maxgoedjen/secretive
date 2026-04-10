@unsafe @preconcurrency import LocalAuthentication
import SecretKit

/// A context describing a persisted authentication.
public final class AuthenticationContext: AuthenticationContextProtocol {

    /// The Secret to persist authentication for.
    public let secret: AnySecret
    /// The LAContext used to authorize the persistent context.
    public let laContext: LAContext
    /// An expiration date for the context.
    /// - Note -  Monotonic time instead of Date() to prevent people setting the clock back.
    let monotonicExpiration: UInt64

    /// Initializes a context.
    /// - Parameters:
    ///   - secret: The Secret to persist authentication for.
    ///   - context: The LAContext used to authorize the persistent context.
    ///   - duration: The duration of the authorization context, in seconds.
    init<SecretType: Secret>(secret: SecretType, context: LAContext, duration: TimeInterval) {
        self.secret = AnySecret(secret)
        self.laContext = context
        let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
        self.monotonicExpiration = clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds)
    }

    /// A boolean describing whether or not the context is still valid.
    public var valid: Bool {
        clock_gettime_nsec_np(CLOCK_MONOTONIC) < monotonicExpiration
    }

    public var expiration: Date {
        let remainingNanoseconds = monotonicExpiration - clock_gettime_nsec_np(CLOCK_MONOTONIC)
        let remainingInSeconds = Measurement(value: Double(remainingNanoseconds), unit: UnitDuration.nanoseconds).converted(to: .seconds).value
        return Date(timeIntervalSinceNow: remainingInSeconds)
    }

}

public actor AuthenticationHandler: Sendable {

    private var persistedContexts: [AnySecret: AuthenticationContext] = [:]

    public init() {
    }

    public nonisolated func createAuthenticationContext<SecretType: Secret>(secret: SecretType, provenance: SigningRequestProvenance, preauthorize: Bool) -> AuthenticationContextProtocol {
        let newContext = LAContext()
        newContext.localizedReason = String(localized: .authContextRequestSignatureDescription(appName: provenance.origin.displayName, secretName: secret.name))
        newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)
        return AuthenticationContext(secret: secret, context: newContext, duration: 0)
    }

    public func existingAuthenticationContextProtocol<SecretType: Secret>(secret: SecretType) -> AuthenticationContextProtocol? {
        guard let persisted = persistedContexts[AnySecret(secret)], persisted.valid else { return nil }
        return persisted
    }

    public func persistAuthentication<SecretType: Secret>(secret: SecretType, forDuration duration: TimeInterval) async throws {
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
        let context = AuthenticationContext(secret: secret, context: newContext, duration: duration)
        persistedContexts[AnySecret(secret)] = context
    }

}

