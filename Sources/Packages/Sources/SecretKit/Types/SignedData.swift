import Foundation

/// Describes the output of a sign request.
public struct SignedData {

    /// The signed data.
    public let data: Data
    /// A boolean describing whether authentication was required during the signature process.
    public let requiredAuthentication: Bool

    /// Initializes a new SignedData.
    /// - Parameters:
    ///   - data: The signed data.
    ///   - requiredAuthentication: A boolean describing whether authentication was required during the signature process.
    public init(data: Data, requiredAuthentication: Bool) {
        self.data = data
        self.requiredAuthentication = requiredAuthentication
    }

}
