import Foundation
import Security
import CryptoTokenKit

// TODO: Might need to split this up into "sub-stores?"
// ie, each token has its own Store.
extension SmartCard {

    public class Store: SecretStore {

        // TODO: Read actual smart card name, eg "YubiKey 5c"
        public let name = NSLocalizedString("Smart Card", comment: "Smart Card")
        @Published public fileprivate(set) var secrets: [Secret] = []
        fileprivate let watcher = TKTokenWatcher()

        public init() {
            watcher.setInsertionHandler { (string) in
                guard !string.contains("setoken") else { return }
                let driver = TKSmartCardTokenDriver()
                let token = TKToken(tokenDriver: driver, instanceID: string)
                let session = TKSmartCardTo kenSession(token: token)
                print(session)

            }
            print(watcher.tokenIDs)
        }

        public func sign(data: Data, with secret: SmartCard.Secret) throws -> Data {
            fatalError()
        }

        public func delete(secret: SmartCard.Secret) throws {
        }

    }
}
