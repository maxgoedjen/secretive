import Foundation
//import SecretKit

//extension SecureEnclave {

public struct Certificate: Sendable, Codable, Equatable, Hashable, Identifiable {

    public var id: Int { hashValue }
    public var type: String
    public let name: String?
    public let data: Data

}

//}
