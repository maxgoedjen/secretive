import Foundation
import Combine
import SecretKit

extension SecureEnclave {

    /// An implementation of Secret backed by the Secure Enclave.
    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let keyType: KeyType
        public let authenticationRequirement: AuthenticationRequirement
        public let publicKeyAttribution: String?
        public let publicKey: Data

        init(
            id: Data,
            name: String,
            authenticationRequirement: AuthenticationRequirement,
            publicKey: Data,
        ) {
            self.id = id
            self.name = name
            self.keyType = .init(algorithm: .ecdsa, size: 256)
            self.authenticationRequirement = authenticationRequirement
            self.publicKeyAttribution = nil
            self.publicKey = publicKey
        }

        init(
            id: String,
            name: String,
            publicKey: Data,
            attributes: Attributes
        ) {
            self.id = Data(id.utf8)
            self.name = name
            self.keyType = attributes.keyType
            self.authenticationRequirement = attributes.authentication
            self.publicKeyAttribution = attributes.publicKeyAttribution
            self.publicKey = publicKey
        }
    }

}
