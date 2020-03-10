import Foundation
import Combine

extension SmartCard {

    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let algorithm: Algorithm
        public let keySize: Int
        public let publicKey: Data

    }

}
