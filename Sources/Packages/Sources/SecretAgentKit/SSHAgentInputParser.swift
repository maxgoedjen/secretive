import Foundation
import OSLog
import SecretKit

public protocol SSHAgentInputParserProtocol: Sendable {

    func parse(data: Data) async throws -> SSHAgent.Request
    
}

public struct SSHAgentInputParser: SSHAgentInputParserProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "InputParser")

    public init() {
        
    }

    public func parse(data: Data) throws(AgentParsingError) -> SSHAgent.Request {
        logger.debug("Parsing new data")
        guard data.count > 4 else {
            throw .invalidData
        }
        let specifiedLength = (data[0..<4].bytes.unsafeLoad(as: UInt32.self).bigEndian) + 4
        let rawRequestInt = data[4]
        let remainingDataRange = 5..<min(Int(specifiedLength), data.count)
        lazy var body: Data = { Data(data[remainingDataRange]) }()
        switch rawRequestInt {
        case SSHAgent.Request.requestIdentities.protocolID:
            return .requestIdentities
        case SSHAgent.Request.signRequest(.empty).protocolID:
            do {
                return .signRequest(try signatureRequestContext(from: body))
            } catch {
                throw .openSSHReader(error)
            }
        case SSHAgent.Request.addIdentity.protocolID:
            return .addIdentity
        case SSHAgent.Request.removeIdentity.protocolID:
            return .removeIdentity
        case SSHAgent.Request.removeAllIdentities.protocolID:
            return .removeAllIdentities
        case SSHAgent.Request.addIDConstrained.protocolID:
            return .addIDConstrained
        case SSHAgent.Request.addSmartcardKey.protocolID:
            return .addSmartcardKey
        case SSHAgent.Request.removeSmartcardKey.protocolID:
            return .removeSmartcardKey
        case SSHAgent.Request.lock.protocolID:
            return .lock
        case SSHAgent.Request.unlock.protocolID:
            return .unlock
        case SSHAgent.Request.addSmartcardKeyConstrained.protocolID:
            return .addSmartcardKeyConstrained
        case SSHAgent.Request.protocolExtension.protocolID:
            return .protocolExtension
        default:
            return .unknown(rawRequestInt)
        }
    }

}

extension SSHAgentInputParser {

    func signatureRequestContext(from data: Data) throws(OpenSSHReaderError) -> SSHAgent.Request.SignatureRequestContext {
        let reader = OpenSSHReader(data: data)
        let rawKeyBlob = try reader.readNextChunk()
        let keyBlob = certificatePublicKeyBlob(from: rawKeyBlob) ?? rawKeyBlob
        let dataToSign = try reader.readNextChunk()
        return SSHAgent.Request.SignatureRequestContext(keyBlob: keyBlob, dataToSign: dataToSign)
    }

    func certificatePublicKeyBlob(from hash: Data) -> Data? {
        let reader = OpenSSHReader(data: hash)
        do {
            let certType = String(decoding: try reader.readNextChunk(), as: UTF8.self)
            switch certType {
            case "ecdsa-sha2-nistp256-cert-v01@openssh.com",
                "ecdsa-sha2-nistp384-cert-v01@openssh.com",
                "ecdsa-sha2-nistp521-cert-v01@openssh.com":
                _ = try reader.readNextChunk() // nonce
                let curveIdentifier = try reader.readNextChunk()
                let publicKey = try reader.readNextChunk()
                let openSSHIdentifier = certType.replacingOccurrences(of: "-cert-v01@openssh.com", with: "")
                return openSSHIdentifier.lengthAndData +
                curveIdentifier.lengthAndData +
                publicKey.lengthAndData
            default:
                return nil
            }
        } catch {
            return nil
        }
    }

}


extension SSHAgentInputParser {

    public enum AgentParsingError: Error, Codable {
        case unknownRequest
        case unhandledRequest
        case invalidData
        case openSSHReader(OpenSSHReaderError)
    }

}
