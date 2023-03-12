import Foundation
import SecretKit

enum Preview {}

extension Preview {

    struct Secret: SecretKit.Secret {

        let id = UUID().uuidString
        let name: String
        let algorithm = Algorithm.ellipticCurve
        let keySize = 256
        let requiresAuthentication: Bool = false
        let publicKey = UUID().uuidString.data(using: .utf8)!

    }

}

extension Preview {

    class Store: SecretStore, ObservableObject {

        let isAvailable = true
        let id = UUID()
        var name: String { "Preview Store" }
        @Published var secrets: [Secret] = []

        init(secrets: [Secret]) {
            self.secrets.append(contentsOf: secrets)
        }

        init(numberOfRandomSecrets: Int = 5) {
            let new = (0..<numberOfRandomSecrets).map { Secret(name: String(describing: $0)) }
            self.secrets.append(contentsOf: new)
        }

        func sign(data: Data, with secret: Preview.Secret, for provenance: SigningRequestProvenance) throws -> Data {
            return data
        }

        func verify(signature data: Data, for signature: Data, with secret: Preview.Secret) throws -> Bool {
            true
        }

        func existingPersistedAuthenticationContext(secret: Preview.Secret) -> PersistedAuthenticationContext? {
            nil
        }

        func persistAuthentication(secret: Preview.Secret, forDuration duration: TimeInterval) throws {
        }

        func reloadSecrets() {
        }

    }

    class StoreModifiable: Store, SecretStoreModifiable {
        override var name: String { "Modifiable Preview Store" }

        func create(name: String, requiresAuthentication: Bool) throws {
        }

        func delete(secret: Preview.Secret) throws {
        }

        func update(secret: Preview.Secret, name: String) throws {
        }
    }
}

extension Preview {

    static func storeList(stores: [Store] = [], modifiableStores: [StoreModifiable] = []) -> SecretStoreList {
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
