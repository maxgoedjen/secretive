@unsafe @preconcurrency import LocalAuthentication
import SecretKit
import OSLog

/// A context describing a persisted authentication.
public final class AuthenticationContext: AuthenticationContextProtocol {

    /// The Secret to persist authentication for.
    public let secret: AnySecret
    /// The LAContext used to authorize the persistent context.
    public let laContext: LAContext?

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
    ///   - duration: The duration of the authorization context, in seconds.
    init<SecretType: Secret>(secret: SecretType, duration: TimeInterval) {
        self.secret = AnySecret(secret)
        let durationInNanoSeconds = Measurement(value: duration, unit: UnitDuration.seconds).converted(to: .nanoseconds).value
        self.validity = .time(monotonicExpiration: clock_gettime_nsec_np(CLOCK_MONOTONIC) + UInt64(durationInNanoSeconds))
        let newContext = LAContext()
        newContext.touchIDAuthenticationAllowableReuseDuration = duration
        newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .spellOut
        formatter.allowedUnits = [.hour, .minute, .day]
        let durationString = formatter.string(from: duration)!
        newContext.localizedReason = String(localized: .authContextPersistForDuration(secretName: secret.name, duration: durationString))
        laContext = newContext
    }

    init<SecretType: Secret>(secret: SecretType, requests: Set<SignatureRequest>) {
        self.secret = AnySecret(secret)
        if requests.count == 1 {
            self.validity = .exclusive(requests.first!.id)
        } else {
            self.validity = .requestIDs(Set(requests.map(\.id)))
        }
        if secret.authenticationRequirement.required {
            let newContext = LAContext()
            newContext.localizedCancelTitle = String(localized: .authContextRequestDenyButton)
            let appName = requests.first!.provenance.origin.displayName
            if requests.count > 1 {
                newContext.localizedReason = String(localized: .authContextRequestMultiple(appName: appName, secretName: secret.name))
            } else {
                newContext.localizedReason = String(localized: .authContextRequestSignatureDescription(appName: appName, secretName: secret.name))
            }
            laContext = newContext
        } else {
            laContext = nil
        }
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

    public func evaluate() async throws -> Bool {
        guard let laContext else { return false }
        return try await laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: laContext.localizedReason)
    }

    public func cancel() async {
        laContext?.invalidate()
    }

}

@MainActor public protocol AuthenticationHandlerProtocol: Observable {
    var batchableRequests: [[SignatureRequest]] { get }
    func setPendingRequestHandler(_ handler: @escaping () async throws -> Void)
    func authenticatedContext(for request: SignatureRequest, context: any AuthenticationContextProtocol) async throws -> (any AuthenticationContextProtocol)?
    func persistAuthentication<SecretType: Secret>(secret: SecretType, forDuration duration: TimeInterval) async throws
    func requestAuthentication(for requests: Set<SignatureRequest>) async throws
}

@Observable @MainActor public class AuthenticationHandler: AuthenticationHandlerProtocol {

    private var authenticatedContexts: [AnySecret: AuthenticationContext] = [:]
    private var waitingRequests: Set<SignatureRequest> = []
    private var activeTask: Task<Bool, any Error>?
    private var activeContext: (any AuthenticationContextProtocol)?

    private var lastBatchAuthPresentation: Set<SignatureRequest>?
    private var presentPendingAuth: (() async throws -> Void)?
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "AuthenticationHandler")

    public init() {
    }

    public func setPendingRequestHandler(_ handler: @escaping () async throws -> Void) {
        self.presentPendingAuth = handler
    }

    public func authenticatedContext(for request: SignatureRequest, context: any AuthenticationContextProtocol) async throws -> (any AuthenticationContextProtocol)? {
        if request.secret.authenticationRequirement.required {
            // Slow path, will block caller until authenticated (either directly or via a pending requests view).
            return try await waitForAuthentication(for: request, context: context)
        } else {
            // Fast path, no blocking/enqueing required
            return context
        }
    }

    func waitForAuthentication(for request: SignatureRequest, context: any AuthenticationContextProtocol) async throws -> any AuthenticationContextProtocol {
        logger.log("Entering waitForAuthentication for \(request.id)")
        if let existing = existingAuthenticationContext(for: request) {
            logger.log("Short circuiting wait, existing valid context already exists.")
            return existing
        }
        waitingRequests.insert(request)
        logger.log("Waiting for authentication for \(request.id)")
        defer {
            logger.log("Removed hold for \(request.id)")
            waitingRequests.remove(request)
        }

        if waitingRequests.count > 1 {
            return try await waitUntilRequestActedOn(request)
        }

        // Hold onto the task and context so we can cancel them when prsenting pending.
        activeContext = context
        let currentTask = Task<Bool, any Error> {
            logger.log("Beginning individual auth prompt")
            let result = (try? await context.evaluate()) ?? false
            logger.log("Ended individual auth prompt")
            return result
        }
        activeTask = currentTask
        let result = try? await activeTask?.value
        if result == false && activeTask?.isCancelled == false {
            waitingRequests.remove(request)
            throw CancellationError()
        } else if currentTask.isCancelled {
            return try await waitUntilRequestActedOn(request)
        }
        return context
    }

    func waitUntilRequestActedOn(_ request: SignatureRequest) async throws -> any AuthenticationContextProtocol {
        logger.log("Auth prompt was cancelled, waiting for explicit auth")
        // At this point, we essentially just block the task until either the request has been authenticated "externally" via the pending view.
        while waitingRequests.contains(request) {
            if waitingRequests != lastBatchAuthPresentation {
                // If we're about to present a batch, we cancel the individual auth prompt, and show the batch one.
                logger.log("Multiple pending requests exist, cancelling existing auth prompt")
                activeTask?.cancel()
                lastBatchAuthPresentation = waitingRequests
                logger.log("Requesting pending requests presentation")
                try await presentPendingAuth?()
                await activeContext?.cancel()
                logger.log("Requested pending requests presentation")
            }
            if let preauthenticated = existingAuthenticationContext(for: request) {
                logger.log("Explicit auth context found")
                return preauthenticated
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw CancellationError()

    }

    public var batchableRequests: [[SignatureRequest]] {
        waitingRequests.reduce(into: [:]) { partialResult, next in
            partialResult[next.batchID, default: []].append(next)
        }
        .values
        .map { $0.sorted() }
    }

    private func existingAuthenticationContext(for request: SignatureRequest) -> (any AuthenticationContextProtocol)? {
        guard let authenticated = authenticatedContexts[request.secret], authenticated.valid(for: request) else { return nil }
        return authenticated
    }

    public func persistAuthentication<SecretType: Secret>(secret: SecretType, forDuration duration: TimeInterval) async throws {
        let context = AuthenticationContext(secret: secret, duration: duration)
        let success = try await context.evaluate()
        guard success else { return }
        authenticatedContexts[AnySecret(secret)] = context
    }

    public func requestAuthentication(for requests: Set<SignatureRequest>) async throws {
        activeTask?.cancel()
        guard let first = requests.first else { return }
        let context = AuthenticationContext(secret: first.secret, requests: requests)
        let success = (try? await context.evaluate()) ?? false
        guard success else {
            waitingRequests.subtract(requests)
            return
        }
        // Even single-use ones get stuffed into authenticatedContexts, so that it can unblock the response path.
        authenticatedContexts[AnySecret(first.secret)] = context
    }

}

