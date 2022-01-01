import Foundation
import XCTest
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit

class AnySecretTests: XCTestCase {

    func testEraser() {
        let secret = SmartCard.Secret(id: UUID().uuidString.data(using: .utf8)!, name: "Name", algorithm: .ellipticCurve, keySize: 256, publicKey: UUID().uuidString.data(using: .utf8)!)
        let erased = AnySecret(secret)
        XCTAssert(erased.id == secret.id as AnyHashable)
        XCTAssert(erased.name == secret.name)
        XCTAssert(erased.algorithm == secret.algorithm)
        XCTAssert(erased.keySize == secret.keySize)
        XCTAssert(erased.publicKey == secret.publicKey)
    }

}
