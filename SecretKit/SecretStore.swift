import Combine

public protocol SecretStore: ObservableObject {

    associatedtype SecretType: Secret
    var name: String { get }
    var secrets: [SecretType] { get }

    func sign(data: Data, with secret: SecretType) throws -> Data
    func delete(secret: SecretType) throws

}

extension NSNotification.Name {

    static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")

}
