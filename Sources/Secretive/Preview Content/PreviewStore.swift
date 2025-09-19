import Foundation
import SecretKit

enum Preview {}

extension Preview {

    struct Secret: SecretKit.Secret {

        let id = UUID().uuidString
        let name: String
        let publicKey = Data(UUID().uuidString.utf8)
        var attributes: Attributes {
            Attributes(
                keyType: .init(algorithm: .ecdsa, size: 256),
                authentication: .presenceRequired,
            )
        }
    }

}

extension Preview {

    @Observable final class Store: SecretStore {

        let isAvailable = true
        let id = UUID()
        var name: String { "Preview Store" }
        let secrets: [Secret]

        init(secrets: [Secret]) {
            self.secrets = secrets
        }

        convenience init(numberOfRandomSecrets: Int = 5) {
            let new = (0..<numberOfRandomSecrets).map { Secret(name: String(describing: $0)) }
            self.init(secrets: new)
        }

        func sign(data: Data, with secret: Preview.Secret, for provenance: SigningRequestProvenance) throws -> Data {
            return data
        }

        func existingPersistedAuthenticationContext(secret: Preview.Secret) -> PersistedAuthenticationContext? {
            nil
        }

        func persistAuthentication(secret: Preview.Secret, forDuration duration: TimeInterval) throws {
        }

        func reloadSecrets() {
        }

    }

    final class StoreModifiable: SecretStoreModifiable {
        
        let isAvailable = true
        let id = UUID()
        var name: String { "Modifiable Preview Store" }
        let secrets: [Secret]
        var supportedKeyTypes: KeyAvailability {
            return KeyAvailability(
                available: [
                    .ecdsa256,
                    .mldsa65,
                    .mldsa87
                ],
                unavailable: [
                    .init(keyType: .ecdsa384, reason: .macOSUpdateRequired)
                ]
            )
        }
        
        init(secrets: [Secret]) {
            self.secrets = secrets
        }

        convenience init(numberOfRandomSecrets: Int = 5) {
            let new = (0..<numberOfRandomSecrets).map { Secret(name: String(describing: $0)) }
            self.init(secrets: new)
        }

        func sign(data: Data, with secret: Preview.Secret, for provenance: SigningRequestProvenance) throws -> Data {
            return data
        }

        func existingPersistedAuthenticationContext(secret: Preview.Secret) -> PersistedAuthenticationContext? {
            nil
        }

        func persistAuthentication(secret: Preview.Secret, forDuration duration: TimeInterval) throws {
        }

        func reloadSecrets() {
        }


        func create(name: String, attributes: Attributes) throws -> Secret {
            fatalError()
        }

        func delete(secret: Preview.Secret) throws {
        }

        func update(secret: Preview.Secret, name: String, attributes: Attributes) throws {
        }
    }
}

extension Preview {

    @MainActor static func storeList(stores: [Store] = [], modifiableStores: [StoreModifiable] = []) -> SecretStoreList {
        let list = SecretStoreList()
        for store in stores {
            list.add(store: store)
        }
        for storeModifiable in modifiableStores {
            list.add(store: storeModifiable)
        }
        return list
    }

}
