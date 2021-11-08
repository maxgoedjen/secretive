import Combine

public protocol SecretStore: ObservableObject, Identifiable {

    associatedtype SecretType: Secret

    var isAvailable: Bool { get }
    var id: UUID { get }
    var name: String { get }
    var secrets: [SecretType] { get }

    func sign(data: Data, with secret: SecretType, for provenance: SigningRequestProvenance) throws -> SignedData

    func persistAuthentication(secret: SecretType, forDuration duration: TimeInterval) throws

}

public protocol SecretStoreModifiable: SecretStore {

    func create(name: String, requiresAuthentication: Bool) throws
    func delete(secret: SecretType) throws
    func update(secret: SecretType, name: String) throws

}

extension NSNotification.Name {

    static let secretStoreUpdated = NSNotification.Name("com.maxgoedjen.Secretive.secretStore.updated")

}
