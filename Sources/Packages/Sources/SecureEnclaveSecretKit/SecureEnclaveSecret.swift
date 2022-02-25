import Foundation
import Combine
import SecretKit

extension SecureEnclave {

    /// An implementation of Secret backed by the Secure Enclave.
    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let algorithm = Algorithm.ellipticCurve
        public let keySize = 256
        public let requiresAuthentication: Bool
        public let publicKey: Data

    }

}
