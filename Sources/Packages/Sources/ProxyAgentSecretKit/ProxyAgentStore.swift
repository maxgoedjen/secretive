import Foundation
import Security
import CryptoTokenKit
import LocalAuthentication
import SecretKit

extension ProxyAgent {

    /// An implementation of Store backed by a Proxy Agent.
    public class Store: SecretStore {

        @Published public var isAvailable: Bool = true
        public let id = UUID()
        public private(set) var name = NSLocalizedString("Proxy SSH Agent", comment: "Proxy SSH Agent")
        @Published public private(set) var secrets: [Secret] = []
        private let agentPath: String

        /// Initializes a Store.
        public init(path: String) {
            agentPath = path
            secrets.append(Secret(id: "hello".data(using: .utf8)!, name: "Test", algorithm: .ellipticCurve, keySize: 256, publicKey: Data(base64Encoded: "AAAAC3NzaC1lZDI1NTE5AAAAIINQz8WohBS46ICEUtkJ/vdxJPM63T5Dy4bQC35JVgGR")!))
        }

        // MARK: Public API

        public func create(name: String) throws {
            fatalError("Keys must be created on the smart card.")
        }

        public func delete(secret: Secret) throws {
            fatalError("Keys must be deleted on the smart card.")
        }

        public func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> Data {
            fatalError()
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
    }

}
