import Foundation
import Combine

extension SecureEnclave {

    public struct Secret: SecretKit.Secret {
        public init(id: Data, name: String, publicKey: Data) {
            self.id = id
            self.name = name
            self.publicKey = publicKey
        }


        public let id: Data
        public let name: String
        public let publicKey: Data



    }

}
