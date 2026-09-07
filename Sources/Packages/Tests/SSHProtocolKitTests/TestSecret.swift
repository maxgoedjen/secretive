import Foundation
import SecretKit

public struct TestSecret: SecretKit.Secret {
    
    public let id: Data
    public let name: String
    public let publicKey: Data
    public var attributes: Attributes
    
}
