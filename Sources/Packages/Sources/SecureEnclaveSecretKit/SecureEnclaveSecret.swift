import Foundation
import Combine
import SecretKit

extension SecureEnclave {

    public struct Secret: SecretKit.Secret {

        public let id: Data
        public let name: String
        public let algorithm = Algorithm.ellipticCurve
        public let keySize = 256
        public let publicKey: Data

    }

}
