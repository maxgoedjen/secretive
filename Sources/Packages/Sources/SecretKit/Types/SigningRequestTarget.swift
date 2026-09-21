import Foundation
import AppKit

/// Describes the target of the signature operation.
public enum SigningRequestTarget: Sendable, Hashable {

    case connection(ConnectionPayload)
    case signature(SignaturePayload)

    public var batchID: Int {
        hashValue
    }


    public struct ConnectionPayload: Sendable, Codable, Hashable {

        public let username: String
        public let hasSignature: Bool
        public let publicKeyAlgorithm: String
        public let publicKey: Data
        public let hostKey: Data
        public let host: String?

        public init(
            username: String,
            hasSignature: Bool,
            publicKeyAlgorithm: String,
            publicKey: Data,
            hostKey: Data,
            host: String?
        ) {
            self.username = username
            self.hasSignature = hasSignature
            self.publicKeyAlgorithm = publicKeyAlgorithm
            self.publicKey = publicKey
            self.hostKey = hostKey
            self.host = host
        }

    }

    public struct SignaturePayload: Sendable, Codable, Hashable {

        public let namespace: String
        public let hashAlgorithm: String
        public let hash: Data

        public init(
            namespace: String,
            hashAlgorithm: String,
            hash: Data,
        ) {
            self.namespace = namespace
            self.hashAlgorithm = hashAlgorithm
            self.hash = hash
        }

    }

}
