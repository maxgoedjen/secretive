import Foundation
import SecretKit

extension SecureEnclave {

    /// An implementation of Secret backed by the Secure Enclave.
    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let publicKey: Data
        public let attributes: Attributes

        init(
            id: Data,
            name: String,
            authenticationRequirement: AuthenticationRequirement,
            publicKey: Data,
        ) {
            self.id = id
            self.name = name
            self.publicKey = publicKey
            self.attributes = Attributes(
                keyType: .init(
                    algorithm: .ecdsa,
                    size: 256
                ),
                authentication: authenticationRequirement,
                publicKeyAttribution: nil
            )
        }

        init(
            id: String,
            name: String,
            publicKey: Data,
            attributes: Attributes
        ) {
            self.id = Data(id.utf8)
            self.name = name
            self.publicKey = publicKey
            self.attributes = attributes
        }
    }

}
