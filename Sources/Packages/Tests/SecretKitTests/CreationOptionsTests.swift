import Foundation
import Security
import Testing
@testable import SecretKit
@testable import SecureEnclaveSecretKit

@Suite struct CreationOptionsTests {

    @Test(arguments: [false, true])
    func encodesLockedScreenUse(_ usableWhileLocked: Bool) throws {
        let attributes = Attributes(
            keyType: .init(algorithm: .ecdsa, size: 256),
            authentication: .notRequired,
            usableWhileLocked: usableWhileLocked
        )
        let encoded = try JSONEncoder().encode(attributes)
        let json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(json["usableWhileLocked"] as? Bool == usableWhileLocked)
    }

    @Test func decodesExistingAttributesAsLockedScreenUseDisabled() throws {
        let existingJSON = Data(#"{"keyType":{"algorithm":{"ecdsa":{}},"size":256},"authentication":"notRequired"}"#.utf8)

        let attributes = try JSONDecoder().decode(Attributes.self, from: existingJSON)

        #expect(attributes.usableWhileLocked == false)
    }

    @Test func selectsProtectionClassFromLockedScreenUse() {
        #expect(SecureEnclave.keyAccessibility(usableWhileLocked: false) == kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        #expect(SecureEnclave.keyAccessibility(usableWhileLocked: true) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    }
}
