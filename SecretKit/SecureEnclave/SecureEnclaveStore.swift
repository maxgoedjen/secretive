import Foundation
import Security

extension SecureEnclave {

    public class Store: SecretStore {

        @Published public fileprivate(set) var secrets: [Secret] = []

        public init() {
            loadSecrets()
        }

        fileprivate func loadSecrets() {
            let secret = Secret(id: "Test")
            secrets.append(secret)
        }

    }

}
