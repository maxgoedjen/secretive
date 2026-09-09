import Foundation
import LocalAuthentication

/// Protocol describing an authentication context. This is an authorization that can be reused for multiple access to a secret that requires authentication for a specific period of time.
public protocol AuthenticationContextProtocol: Sendable, Identifiable {
    /// Whether the context remains valid.

    var secret: AnySecret { get }

    var laContext: LAContext { get }

    func valid(for request: SignatureRequest) -> Bool

}

public struct SignatureRequest: Identifiable, Hashable, Sendable, Comparable {

    public let id: UUID
    public let date: Date
    public let secret: AnySecret
    public let provenance: SigningRequestProvenance

    public init(secret: AnySecret, provenance: SigningRequestProvenance) {
        self.id = UUID()
        self.date = Date()
        self.secret = secret
        self.provenance = provenance
    }

    public var batchID: Int {
        var hasher = Hasher()
        provenance.batchID.hash(into: &hasher)
        secret.id.hash(into: &hasher)
        return hasher.finalize()
    }

    public static func < (lhs: SignatureRequest, rhs: SignatureRequest) -> Bool {
        lhs.date < rhs.date
    }

}
