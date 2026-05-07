import Foundation
import CertificateKit

public protocol OpenSSHCertificateParserProtocol {
    func parse(data: Data) async throws -> OpenSSHCertificate
}

public struct OpenSSHCertificateParser: OpenSSHCertificateParserProtocol, Sendable {

    public init() {
        assert(Bundle.main.bundleURL.pathExtension == "xpc" || ProcessInfo.processInfo.processName == "xctest", "Potentially unsafe parsing code should run in an XPC service")
    }

    public func parse(data: Data) throws(OpenSSHCertificateError) -> OpenSSHCertificate {
        let string = String(decoding: data, as: UTF8.self)
        var elements = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
        guard elements.count >= 2 else {
            throw OpenSSHCertificateError.parsingFailed
        }
        let typeString = elements.removeFirst()
        guard let type = OpenSSHCertificate.CertificateType(rawValue: typeString) else { throw .unsupportedType }
        let encodedKey = elements.removeFirst()
        guard let decoded = Data(base64Encoded: encodedKey)  else {
            throw OpenSSHCertificateError.parsingFailed
        }
        let comment = elements.first
        do {
            let dataParser = OpenSSHReader(data: decoded)
            let publicKeyType = try dataParser.readNextChunkAsString() // Theoretically the same as typeString, but
                .replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
            _ = try dataParser.readNextChunk() // Nonce
            let publicKeyCurveName = try dataParser.readNextChunkAsString()
            let publicKeyData = try dataParser.readNextChunk()
            let publicKey = OpenSSHCertificate.PublicKey(keyType: publicKeyType, curveName: publicKeyCurveName, data: publicKeyData)
            let serialNumber = try dataParser.readNextBytes(as: UInt64.self, convertEndianness: true)
            let role = try dataParser.readNextBytes(as: UInt32.self, convertEndianness: true)
            _ = role
            let keyIdentifier = try dataParser.readNextChunkAsString()
            let principalsReader = try dataParser.readNextChunkAsSubReader()
            var principals: [String] = []
            while !principalsReader.done {
                try principals.append(principalsReader.readNextChunkAsString())
            }
            let validAfter = try dataParser.readNextBytes(as: UInt64.self, convertEndianness: true)
            let validBefore = try dataParser.readNextBytes(as: UInt64.self, convertEndianness: true)
            let validityRange = Date(timeIntervalSince1970: TimeInterval(validAfter))..<Date(timeIntervalSince1970: TimeInterval(validBefore))
            let criticalOptionsReader = try dataParser.readNextChunkAsSubReader()
            var criticalOptions: [String] = []
            while !criticalOptionsReader.done {
                let next = try criticalOptionsReader.readNextChunkAsString()
                if !next.isEmpty {
                    criticalOptions.append(next)
                }
            }
            let extensionsReader = try dataParser.readNextChunkAsSubReader()
            var extensions: [String] = []
            while !extensionsReader.done {
                let next = try extensionsReader.readNextChunkAsString()
                if !next.isEmpty {
                    extensions.append(next)
                }
            }
            _ = try dataParser.readNextChunk() // reserved
            let signingKeyReader = try dataParser.readNextChunkAsSubReader()
            let signingKeyType = try signingKeyReader.readNextChunkAsString()
            let signingKeyCurveName = try signingKeyReader.readNextChunkAsString()
            let signingKeyData = try signingKeyReader.readNextChunk()
            let signingKey = OpenSSHCertificate.PublicKey(keyType: signingKeyType, curveName: signingKeyCurveName, data: signingKeyData)

            return OpenSSHCertificate(
                type: type,
                name: comment ?? keyIdentifier,
                data: decoded,
                publicKey: publicKey,
                principals: principals,
                keyID: keyIdentifier,
                serial: serialNumber,
                validityRange: validityRange,
                criticalOptions: criticalOptions,
                extensions: extensions,
                signingKey: signingKey,
            )
        } catch {
            throw .parsingFailed
        }
    }

}

public enum OpenSSHCertificateError: Error, Codable {
    case unsupportedType
    case parsingFailed
}
