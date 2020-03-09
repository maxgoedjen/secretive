import Foundation
import SecretKit

enum Preview {}

extension Preview {

    struct Secret: SecretKit.Secret {

        let id = UUID().uuidString
        let name: String
        let algorithm = Algorithm.ellipticCurve
        let keySize = 256
        let publicKey = UUID().uuidString.data(using: .utf8)!

    }

}

extension Preview {

    class Store: SecretStore, ObservableObject {

        let isAvailable = true
        let id = UUID()
        let name = "Preview Store"
        @Published var secrets: [Secret] = []

        init(secrets: [Secret]) {
            self.secrets.append(contentsOf: secrets)
        }

        init(numberOfRandomSecrets: Int) {
            let new = (0...numberOfRandomSecrets).map { Secret(name: String(describing: $0)) }
            self.secrets.append(contentsOf: new)
        }

        func sign(data: Data, with secret: Preview.Secret) throws -> Data {
            return data
        }

        func delete(secret: Preview.Secret) throws {
        }

    }

}
