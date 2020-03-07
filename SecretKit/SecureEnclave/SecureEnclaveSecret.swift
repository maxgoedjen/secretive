import Foundation
import Combine

extension SecureEnclave {

    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let publicKey: Data

    }

}
