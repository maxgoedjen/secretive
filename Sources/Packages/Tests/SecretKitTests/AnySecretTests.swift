import Foundation
import Testing
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit


@Suite struct AnySecretTests {

    @Test func eraser() {
        let data = Data(UUID().uuidString.utf8)
        let secret = SmartCard.Secret(id: data, name: "Name", publicKey: data, attributes: Attributes(keyType: KeyType(algorithm: .ecdsa, size: 256), authentication: .notRequired))
        let erased = AnySecret(secret)
        #expect(erased.id == secret.id as AnyHashable)
        #expect(erased.name == secret.name)
        #expect(erased.keyType == secret.keyType)
        #expect(erased.publicKey == secret.publicKey)
    }

}
