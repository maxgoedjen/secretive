import Combine

public protocol SecretStore: ObservableObject, Identifiable {

    associatedtype SecretType: Secret

    var isAvailable: Bool { get }
    var id: UUID { get }
    var name: String { get }
    var secrets: [SecretType] { get }

    func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> Data

}

public protocol SecretStoreModifiable: SecretStore {

    func create(name: String, requiresAuthentication: Bool) throws
    func delete(secret: SecretType) throws
    func update(secret: SecretType, name: String) throws

}

public protocol SecretStoreAuthenticationPersistable: SecretStore {

    func persistAuthentication(secret: SecretType, forDuration: TimeInterval) throws

}

extension NSNotification.Name {

    static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")

}
