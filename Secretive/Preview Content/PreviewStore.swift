import Foundation
import SecretKit

enum Preview {}

extension Preview {

    struct Secret: SecretKit.Secret {

        let id = UUID().uuidString
        var name: String {
            return id
        }

    }

}

extension Preview {

    class Store: SecretStore, ObservableObject {

        @Published var secrets: [Secret] = []

        init(secrets: [Secret]) {
            self.secrets.append(contentsOf: secrets)
        }

        init(numberOfRandomSecrets: Int) {
            let new = (0...numberOfRandomSecrets).map { _ in Secret() }
            self.secrets.append(contentsOf: new)
        }

    }

}
