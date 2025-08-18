import Foundation
import Combine
import SecretKit

extension SmartCard {

    /// An implementation of Secret backed by a Smart Card.
    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let publicKey: Data
        public var attributes: Attributes

    }

}
