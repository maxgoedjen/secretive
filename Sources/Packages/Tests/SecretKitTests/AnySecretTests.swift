import Foundation
import XCTest
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit

final class AnySecretTests: XCTestCase {

    func testEraser() {
        let data = Data(UUID().uuidString.utf8)
        let secret = SmartCard.Secret(id: data, name: "Name", publicKey: data, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 256), authentication: .notRequired))
        let erased = AnySecret(secret)
        XCTAssertEqual(erased.id, secret.id as AnyHashable)
        XCTAssertEqual(erased.name, secret.name)
        XCTAssertEqual(erased.keyType, secret.keyType)
        XCTAssertEqual(erased.publicKey, secret.publicKey)
    }

}
