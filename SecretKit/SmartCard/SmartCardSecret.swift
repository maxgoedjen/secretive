import Foundation
import Combine

extension SmartCard {

    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let publicKey: Data

    }

}
