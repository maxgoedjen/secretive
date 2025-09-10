import Foundation
import SecretKit

extension SecureEnclave {

    /// An implementation of Secret backed by the Secure Enclave.
    public struct Secret: SecretKit.Secret {

        public let id: String
        public let name: String
        public let publicKey: Data
        public let attributes: Attributes

        init(
            id: String,
            name: String,
            publicKey: Data,
            attributes: Attributes
        ) {
            self.id = id
            self.name = name
            self.publicKey = publicKey
            self.attributes = attributes
        }

        public static func ==(lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

    }

}
