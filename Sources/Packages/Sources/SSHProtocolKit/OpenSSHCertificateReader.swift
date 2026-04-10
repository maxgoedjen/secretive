import Foundation

/// Reads OpenSSH certificate blobs and their corresponding public-key lines.
public struct OpenSSHCertificateReader: Sendable {

    /// Initializes the reader.
    public init() {
    }

    /// Parses an OpenSSH public key line containing a certificate.
    /// - Parameter line: A line in `<type> <base64> [comment]` format.
    /// - Returns: A parsed certificate.
    public func readPublicKeyLine(_ line: String) throws(OpenSSHCertificateError) -> ParsedCertificate {
        let parts = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)
        guard parts.count >= 2 else {
            throw .invalidPublicKeyLine
        }
        guard let certificateBlob = Data(base64Encoded: String(parts[1])) else {
            throw .parsingFailed
        }
        var parsedCertificate = try readCertificateBlob(certificateBlob)
        let declaredType = String(parts[0])
        guard declaredType == parsedCertificate.type else {
            throw .typeMismatch
        }
        if parts.count == 3 {
            parsedCertificate.comment = String(parts[2])
        }
        return parsedCertificate
    }

    /// Parses a raw OpenSSH certificate blob.
    /// - Parameter blob: The SSH wire-format certificate blob.
    /// - Returns: A parsed certificate.
    public func readCertificateBlob(_ blob: Data) throws(OpenSSHCertificateError) -> ParsedCertificate {
        let reader = OpenSSHReader(data: blob)
        do {
            let certificateType = try reader.readNextChunkAsString()
            _ = try reader.readNextChunk() // nonce
            let subjectKeyBlob = try subjectKeyBlob(from: reader, certificateType: certificateType)
            let validity = try readSharedCertificateFields(reader)
            return ParsedCertificate(
                certificateBlob: blob,
                subjectKeyBlob: subjectKeyBlob,
                subjectKeyFingerprint: OpenSSHKeyFingerprint.sha256(for: subjectKeyBlob),
                comment: nil,
                type: certificateType,
                validAfter: validity.validAfter,
                validBefore: validity.validBefore
            )
        } catch let certificateError as OpenSSHCertificateError {
            throw certificateError
        } catch {
            throw .parsingFailed
        }
    }

}

extension OpenSSHCertificateReader {

    private func subjectKeyBlob(from reader: OpenSSHReader, certificateType: String) throws(OpenSSHCertificateError) -> Data {
        switch certificateType {
        case let type where type.hasPrefix("ecdsa-sha2-") && type.hasSuffix("-cert-v01@openssh.com"):
            let curveIdentifier = try readChunk(from: reader)
            let publicKey = try readChunk(from: reader)
            let openSSHIdentifier = type.replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
            return openSSHIdentifier.lengthAndData +
            curveIdentifier.lengthAndData +
            publicKey.lengthAndData
        case "ssh-rsa-cert-v01@openssh.com",
            "rsa-sha2-256-cert-v01@openssh.com",
            "rsa-sha2-512-cert-v01@openssh.com":
            let exponent = try readChunk(from: reader)
            let modulus = try readChunk(from: reader)
            return "ssh-rsa".lengthAndData +
            exponent.lengthAndData +
            modulus.lengthAndData
        case let type where type.hasPrefix("ssh-mldsa-") && type.hasSuffix("-cert-v01@openssh.com"),
            let type where type.hasPrefix("ssh-ed25519-") && type.hasSuffix("-cert-v01@openssh.com"):
            let publicKey = try readChunk(from: reader)
            let openSSHIdentifier = type.replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
            return openSSHIdentifier.lengthAndData + publicKey.lengthAndData
        default:
            throw .unsupportedType
        }
    }

    private func readSharedCertificateFields(_ reader: OpenSSHReader) throws(OpenSSHCertificateError) -> CertificateValidity {
        do {
            _ = try reader.readNextBytes(as: UInt64.self) // serial
            _ = try reader.readNextBytes(as: UInt32.self) // cert type
            _ = try reader.readNextChunk() // key ID
            _ = try reader.readNextChunk() // valid principals
            let validAfter = try reader.readNextBytes(as: UInt64.self)
            let validBefore = try reader.readNextBytes(as: UInt64.self)
            _ = try reader.readNextChunk() // critical options
            _ = try reader.readNextChunk() // extensions
            _ = try reader.readNextChunk() // reserved
            _ = try reader.readNextChunk() // signature key
            _ = try reader.readNextChunk() // signature
            guard reader.done else {
                throw OpenSSHCertificateError.parsingFailed
            }
            return CertificateValidity(validAfter: validAfter, validBefore: validBefore)
        } catch {
            throw .parsingFailed
        }
    }

    private func readChunk(from reader: OpenSSHReader) throws(OpenSSHCertificateError) -> Data {
        do {
            return try reader.readNextChunk()
        } catch {
            throw .parsingFailed
        }
    }

}

extension OpenSSHCertificateReader {

    private struct CertificateValidity {
        let validAfter: UInt64
        let validBefore: UInt64
    }

}

extension OpenSSHCertificateReader {

    /// The parsed contents of an OpenSSH certificate.
    public struct ParsedCertificate: Sendable, Hashable {
        public let certificateBlob: Data
        public let subjectKeyBlob: Data
        public let subjectKeyFingerprint: String
        public var comment: String?
        public let type: String
        public let validAfter: UInt64
        public let validBefore: UInt64

        public init(
            certificateBlob: Data,
            subjectKeyBlob: Data,
            subjectKeyFingerprint: String,
            comment: String?,
            type: String,
            validAfter: UInt64,
            validBefore: UInt64
        ) {
            self.certificateBlob = certificateBlob
            self.subjectKeyBlob = subjectKeyBlob
            self.subjectKeyFingerprint = subjectKeyFingerprint
            self.comment = comment
            self.type = type
            self.validAfter = validAfter
            self.validBefore = validBefore
        }

        public func isExpired(at date: Date = .now) -> Bool {
            guard validBefore != .max else {
                return false
            }

            let currentTimestamp = max(0, Int64(date.timeIntervalSince1970))
            return validBefore <= UInt64(currentTimestamp)
        }
    }

    /// Errors produced while parsing OpenSSH certificates.
    public enum OpenSSHCertificateError: LocalizedError, Equatable {
        case unsupportedType
        case invalidPublicKeyLine
        case parsingFailed
        case typeMismatch

        public var errorDescription: String? {
            switch self {
            case .unsupportedType:
                "The certificate type was unsupported."
            case .invalidPublicKeyLine:
                "The public key line was invalid."
            case .parsingFailed:
                "The certificate could not be parsed."
            case .typeMismatch:
                "The declared key type did not match the certificate blob."
            }
        }
    }

}
