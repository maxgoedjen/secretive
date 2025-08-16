import LocalAuthentication
import SecretKit

extension SecureEnclave {

    actor PersistentAuthenticationHandler: Sendable {

        private var persistedAuthenticationContexts: [Secret: PersistentAuthenticationContext] = [:]

        func existingPersistedAuthenticationContext(secret: Secret) -> PersistentAuthenticationContext? {
            guard let persisted = persistedAuthenticationContexts[secret], persisted.valid else { return nil }
            return persisted
        }

        func persistAuthentication(secret: Secret, forDuration duration: TimeInterval) async throws {
            let newContext = LAContext()
            newContext.touchIDAuthenticationAllowableReuseDuration = duration
            newContext.localizedCancelTitle = String(localized: "auth_context_request_deny_button")

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .spellOut
            formatter.allowedUnits = [.hour, .minute, .day]

            if let durationString = formatter.string(from: duration) {
                newContext.localizedReason = String(localized: "auth_context_persist_for_duration_\(secret.name)_\(durationString)")
            } else {
                newContext.localizedReason = String(localized: "auth_context_persist_for_duration_unknown_\(secret.name)")
            }
            let success = try await newContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: newContext.localizedReason)
            guard success else { return }
            let context = PersistentAuthenticationContext(secret: secret, context: newContext, duration: duration)
            persistedAuthenticationContexts[secret] = context
        }

    }

}
