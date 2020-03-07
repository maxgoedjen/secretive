import Foundation
import Combine

extension SmartCard {

    public struct Secret: SecretKit.Secret {
        
        public let id: Data
        public var name: String
        public let publicKey: Data

    }

}
