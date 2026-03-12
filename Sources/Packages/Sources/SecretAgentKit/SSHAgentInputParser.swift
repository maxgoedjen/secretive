import Foundation
import OSLog
import SecretKit
import SSHProtocolKit

import CryptoKit

public protocol SSHAgentInputParserProtocol {

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
        let specifiedLength = unsafe (data[0..<4].bytes.unsafeLoad(as: UInt32.self).bigEndian) + 4
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
        case SSHAgent.Request.protocolExtension(.empty).protocolID:
            return .protocolExtension(try protocolExtension(from: body))
        default:
            return .unknown(rawRequestInt)
        }
    }

}

extension SSHAgentInputParser {

    private enum Constants {
        static let userAuthMagic: UInt8 = 50 // SSH2_MSG_USERAUTH_REQUEST
        static let sshSigMagic = Data("SSHSIG".utf8)
    }

    func signatureRequestContext(from data: Data) throws(OpenSSHReaderError) -> SSHAgent.Request.SignatureRequestContext {
        let reader = OpenSSHReader(data: data)
        let rawKeyBlob = try reader.readNextChunk()
        let keyBlob = certificatePublicKeyBlob(from: rawKeyBlob) ?? rawKeyBlob
        let rawPayload = try reader.readNextChunk()
        let payload: SSHAgent.Request.SignatureRequestContext.SignaturePayload
        do {
            if rawPayload.count > 6 && rawPayload[0..<6] == Constants.sshSigMagic {
                payload = .init(raw: rawPayload, decoded: .sshSig(try sshSigPayload(from: rawPayload[6...])))
            } else {
                payload = .init(raw: rawPayload, decoded: .sshConnection(try sshConnectionPayload(from: rawPayload)))
            }
        } catch {
            payload = .init(raw: rawPayload, decoded: nil)
        }
        return SSHAgent.Request.SignatureRequestContext(keyBlob: keyBlob, dataToSign: payload)
    }

    func sshSigPayload(from data: Data) throws(OpenSSHReaderError) -> SSHAgent.Request.SignatureRequestContext.SignaturePayload.DecodedPayload.SSHSigPayload {
        // https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig#L79
        let payloadReader = OpenSSHReader(data: data)
        let namespace = try payloadReader.readNextChunkAsString()
        _ = try payloadReader.readNextChunk() // reserved
        let hashAlgorithm = try payloadReader.readNextChunkAsString()
        let hash = try payloadReader.readNextChunk()
        return .init(
            namespace: namespace,
            hashAlgorithm: hashAlgorithm,
            hash: hash
        )
    }

    func sshConnectionPayload(from data: Data) throws(OpenSSHReaderError) -> SSHAgent.Request.SignatureRequestContext.SignaturePayload.DecodedPayload.SSHConnectionPayload {
        let payloadReader = OpenSSHReader(data: data)
        _ = try payloadReader.readNextChunk()
        let magic = try payloadReader.readNextBytes(as: UInt8.self, convertEndianness: false)
        guard magic == Constants.userAuthMagic else { throw .incorrectFormat }
        let username = try payloadReader.readNextChunkAsString()
        _ = try payloadReader.readNextChunkAsString() // "ssh-connection"
        _ = try payloadReader.readNextChunkAsString() // "publickey-hostbound-v00@openssh.com"
        let hasSignature = try payloadReader.readNextByteAsBool()
        let algorithm = try payloadReader.readNextChunkAsString()
        let publicKeyReader = try payloadReader.readNextChunkAsSubReader()
        _ = try publicKeyReader.readNextChunk()
        _ = try publicKeyReader.readNextChunk()
        let publicKey = try publicKeyReader.readNextChunk()
        let hostKeyReader = try payloadReader.readNextChunkAsSubReader()
        _ = try hostKeyReader.readNextChunk()
        let hostKey = try hostKeyReader.readNextChunk()
        return .init(
            username: username,
            hasSignature: hasSignature,
            publicKeyAlgorithm: algorithm,
            publicKey: publicKey,
            hostKey: hostKey,
        )
    }

    func protocolExtension(from data: Data) throws(AgentParsingError) -> SSHAgent.ProtocolExtension {
        do {
            let reader = OpenSSHReader(data: data)
            let nameRaw = try reader.readNextChunkAsString()
            let nameSplit = nameRaw.split(separator: "@")
            guard nameSplit.count == 2 else {
                throw AgentParsingError.invalidData
            }
            let (name, domain) = (nameSplit[0], nameSplit[1])
            switch domain {
            case SSHAgent.ProtocolExtension.OpenSSHExtension.domain:
                switch name {
                case SSHAgent.ProtocolExtension.OpenSSHExtension.sessionBind(.empty).name:
                    let hostkeyBlob = try reader.readNextChunkAsSubReader()
                    let hostKeyType = try hostkeyBlob.readNextChunkAsString()
                    let hostKeyData = try hostkeyBlob.readNextChunk()
                    let sessionID = try reader.readNextChunk()
                    let signatureBlob = try reader.readNextChunkAsSubReader()
                    _ = try signatureBlob.readNextChunk() // key type again
                    let signature = try signatureBlob.readNextChunk()
                    let forwarding = try reader.readNextByteAsBool()
                    switch hostKeyType {
                        // FIXME: FACTOR OUT?
                    case "ssh-ed25519":
                        let hostKey = try CryptoKit.Curve25519.Signing.PublicKey(rawRepresentation: hostKeyData)
                        guard hostKey.isValidSignature(signature, for: sessionID) else {
                            throw AgentParsingError.incorrectSignature
                        }
                    case "ecdsa-sha2-nistp256":
                        let hostKey = try CryptoKit.P256.Signing.PublicKey(rawRepresentation: hostKeyData)
                        guard hostKey.isValidSignature(try .init(rawRepresentation: signature), for: sessionID) else {
                            throw AgentParsingError.incorrectSignature
                        }
                    case "ecdsa-sha2-nistp384":
                        let hostKey = try CryptoKit.P384.Signing.PublicKey(rawRepresentation: hostKeyData)
                        guard hostKey.isValidSignature(try .init(rawRepresentation: signature), for: sessionID) else {
                            throw AgentParsingError.incorrectSignature
                        }
                    case "ssh-mldsa-65":
                        if #available(macOS 26.0, *) {
                            let hostKey = try CryptoKit.MLDSA65.PublicKey(rawRepresentation: hostKeyData)
                            guard hostKey.isValidSignature(signature, for: sessionID) else {
                                throw AgentParsingError.incorrectSignature
                            }
                        } else {
                            throw AgentParsingError.unhandledRequest
                        }
                    case "ssh-mldsa-87":
                        if #available(macOS 26.0, *) {
                            let hostKey = try CryptoKit.MLDSA65.PublicKey(rawRepresentation: hostKeyData)
                            guard hostKey.isValidSignature(signature, for: sessionID) else {
                                throw AgentParsingError.incorrectSignature
                            }
                        } else {
                            throw AgentParsingError.unhandledRequest
                        }
                    case "ssh-rsa":
                        // FIXME: HANDLE
                        throw AgentParsingError.unhandledRequest
                    default:
                        throw AgentParsingError.unhandledRequest
                    }
                    let context = SSHAgent.ProtocolExtension.OpenSSHExtension.SessionBindContext(
                        hostKey: hostKeyData,
                        sessionID: sessionID,
                        signature: signature,
                        forwarding: forwarding
                    )
                    return .openSSH(.sessionBind(context))
                default:
                    return .openSSH(.unknown(String(name)))
                }
            default:
                return .unknown(nameRaw)
            }

        } catch let error as OpenSSHReaderError {
            throw .openSSHReader(error)
        } catch let error as AgentParsingError {
            throw error
        } catch {
            throw .unknownRequest
        }
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
        case incorrectSignature
        case openSSHReader(OpenSSHReaderError)
    }

}
