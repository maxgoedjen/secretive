import Foundation
import Security
import CryptoTokenKit

extension SmartCard {

    public class Store: SecretStore {

        // TODO: Read actual smart card name, eg "YubiKey 5c"
        public let name = NSLocalizedString("Smart Card", comment: "Smart Card")
        @Published public fileprivate(set) var secrets: [Secret] = []
        fileprivate let watcher = TKTokenWatcher()

        public init() {
            watcher.setInsertionHandler { (string) in
                print(string)
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
