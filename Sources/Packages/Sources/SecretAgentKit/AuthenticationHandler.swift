@unsafe @preconcurrency import LocalAuthentication
import SecretKit
import OSLog

/// A context describing a persisted authentication.
public final class AuthenticationContext: AuthenticationContextProtocol {

    /// The Secret to persist authentication for.
    public let secret: AnySecret
    /// The LAContext used to authorize the persistent context.
    public let laContext: LAContext

    enum Validity {
        /// - Note -  Monotonic time instead of Date() to prevent people setting the clock back.
        case time(monotonicExpiration: UInt64)
        case requestIDs(Set<UUID>)
        case exclusive(UUID)
    }

    let validity: Validity

    /// Initializes a context.
    /// - Parameters:
    ///   - secret: The Secret to persist authentication for.
    ///   - context: The LAContext used to authorize the persistent context.
    ///   - duration: The duration of the authorization context, in seconds.
    init<SecretType: Secret>(secret: SecretType, context: LAContext, duration: TimeInterval) {
        self.secret = AnySecret(secret)
        self.laContext = context
        let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
        self.validity = .time(monotonicExpiration: clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds))
    }

    init<SecretType: Secret>(secret: SecretType, context: LAContext, requestIDs: Set<UUID>) {
        self.secret = AnySecret(secret)
        self.laContext = context
        self.validity = .requestIDs(requestIDs)
    }

    init<SecretType: Secret>(secret: SecretType, context: LAContext, requestID: UUID) {
        self.secret = AnySecret(secret)
        self.laContext = context
        self.validity = .exclusive(requestID)
    }

    /// A boolean describing whether or not the context is still valid.
    public func valid(for request: SignatureRequest) -> Bool {
        switch validity {
        case .time(let monotonicExpiration):
            clock_gettime_nsec_np(CLOCK_MONOTONIC) < monotonicExpiration
        case .requestIDs(let set):
            set.contains(request.id)
        case .exclusive(let id):
            id == request.id
        }
    }

}

public actor AuthenticationHandler {

    private var persistedContexts: [AnySecret: AuthenticationContext] = [:]
    private var holdingRequests: Set<SignatureRequest> = []
    private var activeTask: Task<Void, any Error>?

    private var lastBatchAuthPresentation: Set<SignatureRequest>?
    private var presentBatchAuth: (([[SignatureRequest]], @escaping @Sendable (Set<SignatureRequest>) async throws -> Void) async throws -> Void)?
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "Agent")

    public init() {
    }

    public func setBatchAuthHandler(_ handler: @escaping (@Sendable ([[SignatureRequest]], @escaping @Sendable (Set<SignatureRequest>) async throws -> Void) async throws -> Void)) {
        self.presentBatchAuth = handler
    }

    public func waitForAuthentication(for request: SignatureRequest) async throws -> any AuthenticationContextProtocol {
        logger.log("Entering waitForAuthentication for \(request.id)")
        if let existing = existingAuthenticationContext(for: request) {
            logger.log("Short circuiting wait, existing valid context already exists.")
            return existing
        }
        holdingRequests.insert(request)
        logger.log("Waiting for authentication for \(request.id)")
        defer {
            logger.log("Removed hold for \(request.id)")
            holdingRequests.remove(request)
        }
        while holdingRequests.count > 1 {
            if hasBatchableRequests, holdingRequests != lastBatchAuthPresentation {
                logger.log("Batchable requests exist, cancelling existing auth prompt")
                activeTask?.cancel()
                lastBatchAuthPresentation = holdingRequests
                logger.log("Requesting batch auth presentation")
                try await presentBatchAuth?(batchableRequests, persistAuthentication(for:))
                logger.log("Requested batch auth presentation")
            }
            if let preauthorized = existingAuthenticationContext(for: request) {
                logger.log("Batch auth context found, proceededing with preauthorized context")
                return preauthorized
            } else {
                logger.log("Waiting for batch request handling")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let laContext = LAContext()
        laContext.localizedReason = String(localized: .authContextRequestSignatureDescription(appName: request.provenance.origin.displayName, secretName: request.secret.name))
        laContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)
        let context = AuthenticationContext(secret: request.secret, context: laContext, requestID: request.id)

        activeTask = Task {
            logger.log("Beginning individual auth prompt")
            try await Task.sleep(for: .seconds(1000))
//            _ = try? await laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: laContext.localizedReason)
            logger.log("Ended individual auth prompt")
        }
        _ = try await activeTask?.value
        // TODO: Check something beyond cancellation? id?
        // Is this okay? Do we always assume that a cancelled task will be the proceeded on?
        if activeTask?.isCancelled ?? false {
            logger.log("Auth prompt was cancelled, waiting for explicit auth")
            // If we explicitly cancelled the task, hang on until we auth it.
            while true {
                if let preauthorized = existingAuthenticationContext(for: request) {
                    logger.log("Explicit auth context found")
                    return preauthorized
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        return context
    }

    private var batchableRequests: [[SignatureRequest]] {
        holdingRequests.reduce(into: [:]) { partialResult, next in
            partialResult[next.batchID, default: []].append(next)
        }
        .values
        .map { $0.sorted() }
    }

    private var hasBatchableRequests: Bool {
        guard presentBatchAuth != nil else { return false }
        return batchableRequests.count < holdingRequests.count
    }

    private func existingAuthenticationContext(for request: SignatureRequest) -> (any AuthenticationContextProtocol)? {
        guard let persisted = persistedContexts[request.secret], persisted.valid(for: request) else { return nil }
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

    private func persistAuthentication(for requests: Set<SignatureRequest>) async throws {
        activeTask?.cancel()
        guard let first = requests.first else { return }
        let newContext = LAContext()
        newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)

        newContext.localizedReason = String("Multiple")
//        newContext.localizedReason = String(localized: .authContextPersistForDuration(secretName: secret.name, duration: durationString))
        let success = try await newContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: newContext.localizedReason)
        guard success else { return }
        let context = AuthenticationContext(secret: first.secret, context: newContext, requestIDs: Set(requests.map(\.id)))
        persistedContexts[AnySecret(first.secret)] = context
    }

}

