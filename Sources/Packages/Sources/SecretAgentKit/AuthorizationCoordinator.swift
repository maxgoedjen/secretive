import Foundation
import SecretKit
import os
import LocalAuthentication

struct PendingRequest: Identifiable, Hashable, CustomStringConvertible {
    let id: UUID = UUID()
    let secret: AnySecret
    let provenance: SigningRequestProvenance

    var description: String {
        "\(id.uuidString) - \(secret.name) \(provenance.origin.displayName)"
    }

    func batchable(with request: PendingRequest) -> Bool {
        secret == request.secret &&
        provenance.isSameProvenance(as: request.provenance)
    }
}

enum Decision {
    case proceed
    case promptForSharedAuth
}

actor RequestHolder {

    var pending: [PendingRequest] = []
    var authorizing: PendingRequest?
    var preauthorized: PendingRequest?

    func addPending(_ request: PendingRequest) {
        pending.append(request)
    }

    func advanceIfIdle() {

    }

    func shouldBlock(_ request: PendingRequest) -> Bool {
        guard request != authorizing else { return false }
        if let preauthorized, preauthorized.batchable(with: request) {
            print("Batching: \(request)")
            pending.removeAll(where: { $0 == request })
            return false
        }
        return authorizing == nil && authorizing.
    }

    func clear() {
        if let preauthorized, allBatchable(with: preauthorized).isEmpty {
            self.preauthorized = nil
        }
    }

    func allBatchable(with request: PendingRequest) -> [PendingRequest] {
        pending.filter { $0.batchable(with: request) }
    }

    func completedPersistence(secret: AnySecret, forProvenance provenance: SigningRequestProvenance) {
        self.preauthorized = PendingRequest(secret: secret, provenance: provenance)
    }

    func didNotCompletePersistence(secret: AnySecret, forProvenance provenance: SigningRequestProvenance) {
        self.preauthorized = nil
    }
}

final class AuthorizationCoordinator: Sendable {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "AuthorizationCoordinator")
    private let holder = RequestHolder()

    public func waitForAccessIfNeeded(to secret: AnySecret, provenance: SigningRequestProvenance) async throws -> Decision {
        // Block on unknown, since we don't really have any way to check.
        if secret.authenticationRequirement == .unknown {
            logger.warning("\(secret.name) has unknown authentication requirement.")
        }
        guard secret.authenticationRequirement != .notRequired else {
            logger.debug("\(secret.name) does not require authentication, continuing.")
            return .proceed
        }
        logger.debug("\(secret.name) requires authentication.")
        let pending = PendingRequest(secret: secret, provenance: provenance)
        await holder.addPending(pending)
        while await holder.shouldBlock(pending) {
            logger.debug("\(pending) waiting.")
            try await Task.sleep(for: .milliseconds(100))
        }
        if await holder.preauthorized == nil, await holder.allBatchable(with: pending).count > 0 {
            logger.debug("\(pending) batch suggestion.")
            return .promptForSharedAuth
        }
        logger.debug("\(pending) continuing")
        return .proceed
    }

    func completedPersistence(secret: AnySecret, forProvenance provenance: SigningRequestProvenance) async {
        await holder.completedPersistence(secret: secret, forProvenance: provenance)
    }

    func didNotCompletePersistence(secret: AnySecret, forProvenance provenance: SigningRequestProvenance) async {
        await holder.didNotCompletePersistence(secret: secret, forProvenance: provenance)
    }
}
