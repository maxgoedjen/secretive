import Foundation
import SecretKit

extension SmartCard {

    /// An implementation of Secret backed by a Smart Card.
    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let algorithm: Algorithm
        public let keySize: Int
        public let requiresAuthentication: Bool = false
        public let publicKey: Data

    }

}
