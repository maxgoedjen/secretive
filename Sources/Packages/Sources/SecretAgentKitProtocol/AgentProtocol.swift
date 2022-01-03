import Foundation

@objc public protocol AgentProtocol {
    func updatedStore(withID: UUID) async throws
}

public struct AgentProtocolStoreNotFoundError: Error {

    public init() {
    }
    
}
