import Combine

public protocol SecretStore: ObservableObject, Identifiable {

    associatedtype SecretType: Secret

    var isAvailable: Bool { get }
    var id: UUID { get }
    var name: String { get }
    var secrets: [SecretType] { get }

    func sign(data: Data, with secret: SecretType) throws -> Data

}

public protocol SecretStoreModifiable: SecretStore {

    func create(name: String, requiresAuthentication: Bool) throws
    func delete(secret: SecretType) throws

}

extension NSNotification.Name {

    static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")

}
