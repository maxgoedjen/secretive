import Foundation

/// Reads OpenSSH public key blobs and their corresponding public-key lines.
public struct OpenSSHPublicKeyReader: Sendable {

    /// Initializes the reader.
    public init() {
    }

    /// Parses an OpenSSH public key line.
    /// - Parameter line: A line in `<type> <base64> [comment]` format.
    /// - Returns: A parsed public key.
    public func readPublicKeyLine(_ line: String) throws(OpenSSHPublicKeyError) -> ParsedPublicKey {
        let parts = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard parts.count >= 2 else {
            throw .invalidPublicKeyLine
        }
        guard let keyBlob = Data(base64Encoded: String(parts[1])) else {
            throw .parsingFailed
        }
        var parsedPublicKey = try readPublicKeyBlob(keyBlob)
        let declaredType = String(parts[0])
        guard declaredType == parsedPublicKey.type else {
            throw .typeMismatch
        }
        if parts.count == 3 {
            parsedPublicKey.comment = String(parts[2])
        }
        return parsedPublicKey
    }

    /// Parses a raw OpenSSH public key blob.
    /// - Parameter blob: The SSH wire-format public key blob.
    /// - Returns: A parsed public key.
    public func readPublicKeyBlob(_ blob: Data) throws(OpenSSHPublicKeyError) -> ParsedPublicKey {
        let reader = OpenSSHReader(data: blob)
        do {
            let keyType = try reader.readNextChunkAsString()
            try validatePublicKeyBody(reader, keyType: keyType)
            return ParsedPublicKey(
                keyBlob: blob,
                fingerprint: OpenSSHKeyFingerprint.sha256(for: blob),
                comment: nil,
                type: keyType
            )
        } catch let publicKeyError as OpenSSHPublicKeyError {
            throw publicKeyError
        } catch {
            throw .parsingFailed
        }
    }

}

extension OpenSSHPublicKeyReader {

    private func validatePublicKeyBody(_ reader: OpenSSHReader, keyType: String) throws(OpenSSHPublicKeyError) {
        switch keyType {
        case let type where type.hasPrefix("ecdsa-sha2-") && !type.hasSuffix("-cert-v01@openssh.com"):
            _ = try readChunk(from: reader)
            _ = try readChunk(from: reader)
        case "ssh-rsa":
            _ = try readChunk(from: reader)
            _ = try readChunk(from: reader)
        case "ssh-ed25519":
            _ = try readChunk(from: reader)
        case let type where type.hasPrefix("ssh-mldsa-") && !type.hasSuffix("-cert-v01@openssh.com"):
            _ = try readChunk(from: reader)
        case let type where type.hasSuffix("-cert-v01@openssh.com"):
            throw .certificateType
        default:
            throw .unsupportedType
        }

        guard reader.done else {
            throw .parsingFailed
        }
    }

    private func readChunk(from reader: OpenSSHReader) throws(OpenSSHPublicKeyError) -> Data {
        do {
            return try reader.readNextChunk()
        } catch {
            throw .parsingFailed
        }
    }

}

extension OpenSSHPublicKeyReader {

    /// The parsed contents of an OpenSSH public key.
    public struct ParsedPublicKey: Sendable, Hashable {
        public let keyBlob: Data
        public let fingerprint: String
        public var comment: String?
        public let type: String

        public init(
            keyBlob: Data,
            fingerprint: String,
            comment: String?,
            type: String
        ) {
            self.keyBlob = keyBlob
            self.fingerprint = fingerprint
            self.comment = comment
            self.type = type
        }
    }

    /// Errors produced while parsing OpenSSH public keys.
    public enum OpenSSHPublicKeyError: LocalizedError, Equatable {
        case unsupportedType
        case certificateType
        case invalidPublicKeyLine
        case parsingFailed
        case typeMismatch

        public var errorDescription: String? {
            switch self {
            case .unsupportedType:
                "The public key type was unsupported."
            case .certificateType:
                "The blob was an OpenSSH certificate, not a bare public key."
            case .invalidPublicKeyLine:
                "The public key line was invalid."
            case .parsingFailed:
                "The public key could not be parsed."
            case .typeMismatch:
                "The declared key type did not match the public key blob."
            }
        }
    }

}
