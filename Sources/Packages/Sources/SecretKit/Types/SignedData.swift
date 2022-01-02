import Foundation

public struct SignedData {

    public let data: Data
    public let requiredAuthentication: Bool

    public init(data: Data, requiredAuthentication: Bool) {
        self.data = data
        self.requiredAuthentication = requiredAuthentication
    }

}
