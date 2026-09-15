import Foundation
import LocalAuthentication

/// Protocol describing an authentication context. This is an authorization that can be reused for multiple access to a secret that requires authentication for a specific period of time.
public protocol AuthenticationContextProtocol: Sendable, Identifiable {
    var secret: AnySecret { get }
    func valid(for request: SignatureRequest) -> Bool
    var laContext: LAContext? { get }
    func evaluate() async throws -> Bool
    func cancel() async
}

public struct SignatureRequest: Identifiable, Hashable, Sendable, Comparable {

    public let id: UUID
    public let date: Date
    public let secret: AnySecret
    public let provenance: SigningRequestProvenance
    public let target: SigningRequestTarget?

    public init(secret: AnySecret, provenance: SigningRequestProvenance, target: SigningRequestTarget?) {
        self.id = UUID()
        self.date = Date()
        self.secret = secret
        self.provenance = provenance
        self.target = target
    }

    public var batchID: Int {
        var hasher = Hasher()
        guard let target else {
            // Requests without target are not permitted to be batched.
            id.hash(into: &hasher)
            return hasher.finalize()
        }
        provenance.batchID.hash(into: &hasher)
        target.batchID.hash(into: &hasher)
        secret.id.hash(into: &hasher)
        return hasher.finalize()
    }

    public static func < (lhs: SignatureRequest, rhs: SignatureRequest) -> Bool {
        lhs.date < rhs.date
    }

}
