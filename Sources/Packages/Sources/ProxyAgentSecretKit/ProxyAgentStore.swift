import Foundation
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension ProxyAgent {

    /// An implementation of Store backed by a Proxy Agent.
    public class Store: SecretStore {

        @Published public var isAvailable: Bool = false
        public let id = UUID()
        public private(set) var name = NSLocalizedString("Proxy SSH Agent", comment: "Proxy SSH Agent")
        @Published public private(set) var secrets: [Secret] = []

        /// Initializes a Store.
        public init() {
        }

        // MARK: Public API

        public func create(name: String) throws {
            fatalError("Keys must be created on the smart card.")
        }

        public func delete(secret: Secret) throws {
            fatalError("Keys must be deleted on the smart card.")
        }

        public func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> Data {
        }

        public func existingPersistedAuthenticationContext(secret: ProxyAgent.Secret) -> PersistedAuthenticationContext? {
            nil
        }

        public func persistAuthentication(secret: ProxyAgent.Secret, forDuration: TimeInterval) throws {
        }

    }

}

extension ProxyAgent.Store {

}

extension ProxyAgent {

    /// A signing-related error.
    public struct SigningError: Error {
        /// The underlying error reported by the API, if one was returned.
        public let error: SecurityError?
    }

}
