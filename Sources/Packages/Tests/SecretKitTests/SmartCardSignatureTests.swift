import CryptoKit
import Foundation
import Security
import Testing
@testable import SecretKit
@testable import SmartCardSecretKit

@Suite struct SmartCardSignatureTests {

    @Test(arguments: [KeyType.ecdsa256, .ecdsa384, .rsa2048])
    func securitySignature(keyType: KeyType) throws {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: try #require(keyType.secAttrKeyType),
            kSecAttrKeySizeInBits: keyType.size,
        ]
        // Ephemeral software keys exercise Security's encoding without a token or PIN.
        let generatedKey = SecKeyCreateRandomKey(attributes as CFDictionary, nil)
        let privateKey = try #require(generatedKey)
        let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
        let algorithm: SecKeyAlgorithm
        switch keyType {
        case .ecdsa256:
            algorithm = .ecdsaSignatureMessageX962SHA256
        case .ecdsa384:
            algorithm = .ecdsaSignatureMessageX962SHA384
        default:
            algorithm = .rsaSignatureMessagePKCS1v15SHA512
        }
        let message = Data("Smart card signing regression".utf8)
        let signedData = SecKeyCreateSignature(privateKey, algorithm, message as CFData, nil)
        let signature = try #require(signedData) as Data
        let rawSignature = try SmartCard.Store.rawSignature(signature, for: keyType)
        let verificationSignature: Data
        switch keyType {
        case .ecdsa256:
            #expect(rawSignature.count == 64)
            verificationSignature = try P256.Signing.ECDSASignature(rawRepresentation: rawSignature).derRepresentation
        case .ecdsa384:
            #expect(rawSignature.count == 96)
            verificationSignature = try P384.Signing.ECDSASignature(rawRepresentation: rawSignature).derRepresentation
        default:
            #expect(rawSignature == signature)
            verificationSignature = rawSignature
        }
        let isValid = SecKeyVerifySignature(
            publicKey, algorithm, message as CFData, verificationSignature as CFData, nil)
        #expect(isValid)
    }

    @Test(arguments: [KeyType.ecdsa256, .ecdsa384])
    func rejectsMalformedDER(keyType: KeyType) {
        #expect(throws: (any Error).self) {
            try SmartCard.Store.rawSignature(Data([0x30, 0x01, 0x02]), for: keyType)
        }
    }

}
