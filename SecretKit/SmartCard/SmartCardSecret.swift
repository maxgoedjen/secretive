import Foundation
import Combine

extension SmartCard {

    public struct Secret: SecretKit.Secret {
        public init(id: Data, name: String, publicKey: Data) {
            self.id = id
//            self.name = name
            self.publicKey = publicKey
        }


        public let id: Data
        public var name: String {
            UUID().uuidString
        }
        public let publicKey: Data

    }

}
