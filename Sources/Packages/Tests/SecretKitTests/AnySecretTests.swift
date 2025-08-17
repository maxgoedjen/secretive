import Foundation
import Testing
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit

@Suite struct AnySecretTests {

    @Test func eraser() {
        let secret = SmartCard.Secret(id: UUID().uuidString.data(using: .utf8)!, name: "Name", algorithm: .ellipticCurve, keySize: 256, publicKey: UUID().uuidString.data(using: .utf8)!)
        let erased = AnySecret(secret)
        #expect(erased.id == secret.id as AnyHashable)
        #expect(erased.name == secret.name)
        #expect(erased.algorithm == secret.algorithm)
        #expect(erased.keySize == secret.keySize)
        #expect(erased.publicKey == secret.publicKey)
    }

}
