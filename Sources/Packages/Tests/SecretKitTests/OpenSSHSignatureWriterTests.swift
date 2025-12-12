import Foundation
import Testing
@testable import SecretKit
@testable import SmartCardSecretKit

@Suite struct OpenSSHSignatureWriterTests {

    private let writer = OpenSSHSignatureWriter()

    @Test func ecdsaMpintStripsUnnecessaryLeadingZeros() throws {
        let secret = Constants.ecdsa256Secret

        // r has a leading 0x00 followed by 0x01 (< 0x80): the mpint must not keep the leading zero.
        let rBytes: [UInt8] = [0x00] + (1...31).map { UInt8($0) }
        let r = Data(rBytes)
        // s has two leading 0x00 bytes followed by 0x7f (< 0x80): the mpint must not keep the leading zeros.
        let sBytes: [UInt8] = [0x00, 0x00, 0x7f] + Array(repeating: UInt8(0x01), count: 29)
        let s = Data(sBytes)
        let rawRepresentation = r + s

        let response = writer.data(secret: secret, signature: rawRepresentation)
        let (parsedR, parsedS) = try parseEcdsaSignatureMpints(from: response)

        #expect(parsedR == Data((1...31).map { UInt8($0) }))
        #expect(parsedS == Data([0x7f] + Array(repeating: UInt8(0x01), count: 29)))
    }

    @Test func ecdsaMpintPrefixesZeroWhenHighBitSet() throws {
        let secret = Constants.ecdsa256Secret

        // r starts with 0x80 (high bit set): mpint must be prefixed with 0x00.
        let r = Data([UInt8(0x80)] + Array(repeating: UInt8(0x01), count: 31))
        let s = Data([UInt8(0x01)] + Array(repeating: UInt8(0x02), count: 31))
        let rawRepresentation = r + s

        let response = writer.data(secret: secret, signature: rawRepresentation)
        let (parsedR, parsedS) = try parseEcdsaSignatureMpints(from: response)

        #expect(parsedR == Data([0x00, 0x80] + Array(repeating: UInt8(0x01), count: 31)))
        #expect(parsedS == Data([0x01] + Array(repeating: UInt8(0x02), count: 31)))
    }

}

private extension OpenSSHSignatureWriterTests {

    enum Constants {
        static let ecdsa256Secret = SmartCard.Secret(
            id: Data(),
            name: "Test Key (ECDSA 256)",
            publicKey: Data(repeating: 0x01, count: 65),
            attributes: Attributes(
                keyType: KeyType(algorithm: .ecdsa, size: 256),
                authentication: .notRequired,
                publicKeyAttribution: "test@example.com"
            )
        )
    }

    enum ParseError: Error {
        case eof
        case invalidLength
        case invalidAlgorithm
    }

    struct Reader {
        var data: Data
        var offset: Int = 0

        mutating func readU32() throws -> Int {
            guard offset + 4 <= data.count else { throw ParseError.eof }
            let value = data[offset..<offset + 4].reduce(0 as UInt32) { ($0 << 8) | UInt32($1) }
            offset += 4
            return Int(value)
        }

        mutating func readBytes(count: Int) throws -> Data {
            guard count >= 0 else { throw ParseError.invalidLength }
            guard offset + count <= data.count else { throw ParseError.eof }
            let out = data[offset..<offset + count]
            offset += count
            return Data(out)
        }

        mutating func readString() throws -> Data {
            let length = try readU32()
            return try readBytes(count: length)
        }
    }

    func parseEcdsaSignatureMpints(from openSSHSignedData: Data) throws -> (r: Data, s: Data) {
        var reader = Reader(data: openSSHSignedData)

        let outerLength = try reader.readU32()
        guard outerLength == (openSSHSignedData.count - 4) else { throw ParseError.invalidLength }

        let algorithm = try reader.readString()
        guard String(data: algorithm, encoding: .utf8) == "ecdsa-sha2-nistp256" else {
            throw ParseError.invalidAlgorithm
        }

        let signatureChunk = try reader.readString()
        var sigReader = Reader(data: signatureChunk)
        let r = try sigReader.readString()
        let s = try sigReader.readString()
        return (r, s)
    }

}

