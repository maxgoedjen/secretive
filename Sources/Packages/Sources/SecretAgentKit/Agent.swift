import Foundation
import CryptoKit
import OSLog
import SecretKit
import AppKit

enum OpenSSHCertificateError: Error {
    case unsupportedType
    case parsingFailed
    case doesNotExist
}

extension OpenSSHCertificateError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupportedType:
            return "The key type was unsupported"
        case .parsingFailed:
            return "Failed to properly parse the SSH certificate"
        case .doesNotExist:
            return "Certificate does not exist"
        }
    }
}

/// The `Agent` is an implementation of an SSH agent. It manages coordination and access between a socket, traces requests, notifies witnesses and passes requests to stores.
public class Agent {

    private let storeList: SecretStoreList
    private let witness: SigningWitness?
    private let writer = OpenSSHKeyWriter()
    private let requestTracer = SigningRequestTracer()
    private let certsPath = (NSHomeDirectory() as NSString).appendingPathComponent("PublicKeys") as String
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent.agent", category: "")

    /// Initializes an agent with a store list and a witness.
    /// - Parameters:
    ///   - storeList: The `SecretStoreList` to make available.
    ///   - witness: A witness to notify of requests.
    public init(storeList: SecretStoreList, witness: SigningWitness? = nil) {
        logger.debug("Agent is running")
        self.storeList = storeList
        self.witness = witness
    }
    
}

extension Agent {

    /// Handles an incoming request.
    /// - Parameters:
    ///   - reader: A ``FileHandleReader`` to read the content of the request.
    ///   - writer: A ``FileHandleWriter`` to write the response to.
    /// - Return value: 
    ///   - Boolean if data could be read
    @discardableResult public func handle(reader: FileHandleReader, writer: FileHandleWriter) -> Bool {
        logger.debug("Agent handling new data")
        let data = Data(reader.availableData)
        guard data.count > 4 else { return false}
        let requestTypeInt = data[4]
        guard let requestType = SSHAgent.RequestType(rawValue: requestTypeInt) else {
            writer.write(OpenSSHKeyWriter().lengthAndData(of: SSHAgent.ResponseType.agentFailure.data))
            logger.debug("Agent returned \(SSHAgent.ResponseType.agentFailure.debugDescription)")
            return true
        }
        logger.debug("Agent handling request of type \(requestType.debugDescription)")
        let subData = Data(data[5...])
        let response = handle(requestType: requestType, data: subData, reader: reader)
        writer.write(response)
        return true
    }

    func handle(requestType: SSHAgent.RequestType, data: Data, reader: FileHandleReader) -> Data {
        // Depending on the launch context (such as after macOS update), the agent may need to reload secrets before acting
        reloadSecretsIfNeccessary()
        var response = Data()
        do {
            switch requestType {
            case .requestIdentities:
                response.append(SSHAgent.ResponseType.agentIdentitiesAnswer.data)
                response.append(identities())
                logger.debug("Agent returned \(SSHAgent.ResponseType.agentIdentitiesAnswer.debugDescription)")
            case .signRequest:
                let provenance = requestTracer.provenance(from: reader)
                response.append(SSHAgent.ResponseType.agentSignResponse.data)
                response.append(try sign(data: data, provenance: provenance))
                logger.debug("Agent returned \(SSHAgent.ResponseType.agentSignResponse.debugDescription)")
            }
        } catch {
            response.removeAll()
            response.append(SSHAgent.ResponseType.agentFailure.data)
            logger.debug("Agent returned \(SSHAgent.ResponseType.agentFailure.debugDescription)")
        }
        let full = OpenSSHKeyWriter().lengthAndData(of: response)
        return full
    }

}

extension Agent {

    /// Lists the identities available for signing operations
    /// - Returns: An OpenSSH formatted Data payload listing the identities available for signing operations.
    func identities() -> Data {
        let secrets = storeList.stores.flatMap(\.secrets)
        var count = UInt32(secrets.count).bigEndian
        let countData = Data(bytes: &count, count: UInt32.bitWidth/8)
        var keyData = Data()

        for secret in secrets {
            let keyBlob: Data
            let curveData: Data
            
            if let (certBlob, certName) = try? checkForCert(secret: secret) {
                keyBlob = certBlob
                curveData = certName
            } else {
                keyBlob = writer.data(secret: secret)
                curveData = writer.curveType(for: secret.algorithm, length: secret.keySize).data(using: .utf8)!
            }
            
            keyData.append(writer.lengthAndData(of: keyBlob))
            keyData.append(writer.lengthAndData(of: curveData))
            
        }
        logger.log("Agent enumerated \(secrets.count) identities")
        return countData + keyData
    }

    /// Notifies witnesses of a pending signature request, and performs the signing operation if none object.
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - provenance: A ``SecretKit.SigningRequestProvenance`` object describing the origin of the request.
    /// - Returns: An OpenSSH formatted Data payload containing the signed data response.
    func sign(data: Data, provenance: SigningRequestProvenance) throws -> Data {
        let reader = OpenSSHReader(data: data)
        var hash = reader.readNextChunk()
        
        // Check if hash is actually an openssh certificate and reconstruct the public key if it is
        if let certPublicKey = try? getPublicKeyFromCert(certBlob: hash) {
            hash = certPublicKey
        }
        
        guard let (store, secret) = secret(matching: hash) else {
            logger.debug("Agent did not have a key matching \(hash as NSData)")
            throw AgentError.noMatchingKey
        }

        if let witness = witness {
            try witness.speakNowOrForeverHoldYourPeace(forAccessTo: secret, from: store, by: provenance)
        }

        let dataToSign = reader.readNextChunk()
        let signed = try store.sign(data: dataToSign, with: secret, for: provenance)
        let derSignature = signed

        let curveData = writer.curveType(for: secret.algorithm, length: secret.keySize).data(using: .utf8)!

        // Convert from DER formatted rep to raw (r||s)

        let rawRepresentation: Data
        switch (secret.algorithm, secret.keySize) {
        case (.ellipticCurve, 256):
            rawRepresentation = try CryptoKit.P256.Signing.ECDSASignature(derRepresentation: derSignature).rawRepresentation
        case (.ellipticCurve, 384):
            rawRepresentation = try CryptoKit.P384.Signing.ECDSASignature(derRepresentation: derSignature).rawRepresentation
        default:
            throw AgentError.unsupportedKeyType
        }


        let rawLength = rawRepresentation.count/2
        // Check if we need to pad with 0x00 to prevent certain
        // ssh servers from thinking r or s is negative
        let paddingRange: ClosedRange<UInt8> = 0x80...0xFF
        var r = Data(rawRepresentation[0..<rawLength])
        if paddingRange ~= r.first! {
            r.insert(0x00, at: 0)
        }
        var s = Data(rawRepresentation[rawLength...])
        if paddingRange ~= s.first! {
            s.insert(0x00, at: 0)
        }

        var signatureChunk = Data()
        signatureChunk.append(writer.lengthAndData(of: r))
        signatureChunk.append(writer.lengthAndData(of: s))

        var signedData = Data()
        var sub = Data()
        sub.append(writer.lengthAndData(of: curveData))
        sub.append(writer.lengthAndData(of: signatureChunk))
        signedData.append(writer.lengthAndData(of: sub))

        if let witness = witness {
            try witness.witness(accessTo: secret, from: store, by: provenance)
        }

        logger.debug("Agent signed request")

        return signedData
    }
    
    /// Reconstructs a public key from a ``Data`` object that contains an OpenSSH certificate. Currently only ecdsa certificates are supported
    /// - Parameter certBlock: The openssh certificate to extract the public key from
    /// - Returns: A ``Data`` object containing the public key in OpenSSH wire format
    func getPublicKeyFromCert(certBlob: Data) throws -> Data {
        let reader = OpenSSHReader(data: certBlob)
        let certType = String(decoding: reader.readNextChunk(), as: UTF8.self)
                
        switch certType {
        case "ecdsa-sha2-nistp256-cert-v01@openssh.com",
            "ecdsa-sha2-nistp384-cert-v01@openssh.com",
            "ecdsa-sha2-nistp521-cert-v01@openssh.com":
            
            _ = reader.readNextChunk() // nonce
            let curveIdentifier = reader.readNextChunk()
            let publicKey = reader.readNextChunk()
            
            if let curveType = certType.replacingOccurrences(of: "-cert-v01@openssh.com", with: "").data(using: .utf8) {
                return writer.lengthAndData(of: curveType) +
                       writer.lengthAndData(of: curveIdentifier) +
                       writer.lengthAndData(of: publicKey)
            } else {
                throw OpenSSHCertificateError.parsingFailed
            }
        default:
            throw OpenSSHCertificateError.unsupportedType
        }
    }
    
    
    /// Attempts to find an OpenSSH Certificate  that corresponds to a ``Secret``
    /// - Parameter secret: The secret to search for a certificate with
    /// - Returns: Two ``Data`` objects containing the certificate and certificate name respectively
    func checkForCert(secret: AnySecret) throws -> (Data, Data) {
        let minimalHex = writer.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        let certificatePath = certsPath.appending("/").appending("\(minimalHex)-cert.pub")
        
        if FileManager.default.fileExists(atPath: certificatePath) {
            logger.debug("Found certificate for \(secret.name)")
            do {
                let certContent = try String(contentsOfFile:certificatePath, encoding: .utf8)
                let certElements = certContent.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
                
                if certElements.count >= 2 {
                    if let certDecoded = Data(base64Encoded: certElements[1] as String) {
                        if certElements.count >= 3 {
                            if let certName = certElements[2].data(using: .utf8) {
                                return (certDecoded, certName)
                            } else if let certName = secret.name.data(using: .utf8) {
                                logger.info("Certificate for \(secret.name) does not have a name tag, using secret name instead")
                                return (certDecoded, certName)
                            } else {
                                throw OpenSSHCertificateError.parsingFailed
                            }
                        }
                    } else {
                        logger.warning("Certificate found for \(secret.name) but failed to decode base64 key")
                        throw OpenSSHCertificateError.parsingFailed
                    }
                }
            } catch {
                logger.warning("Certificate found for \(secret.name) but failed to load")
                throw OpenSSHCertificateError.parsingFailed
            }
        }
        
        throw OpenSSHCertificateError.doesNotExist
    }

}

extension Agent {

    /// Gives any store with no loaded secrets a chance to reload.
    func reloadSecretsIfNeccessary() {
        for store in storeList.stores {
            if store.secrets.isEmpty {
                logger.debug("Store \(store.name, privacy: .public) has no loaded secrets. Reloading.")
                store.reloadSecrets()
            }
        }
    }

    /// Finds a ``Secret`` matching a specified hash whos signature was requested.
    /// - Parameter hash: The hash to match against.
    /// - Returns: A ``Secret`` and the ``SecretStore`` containing it, if a match is found.
    func secret(matching hash: Data) -> (AnySecretStore, AnySecret)? {
        storeList.stores.compactMap { store -> (AnySecretStore, AnySecret)? in
            let allMatching = store.secrets.filter { secret in
                hash == writer.data(secret: secret)
            }
            if let matching = allMatching.first {
                return (store, matching)
            }
            return nil
        }.first
    }

}


extension Agent {

    /// An error involving agent operations..
    enum AgentError: Error {
        case unhandledType
        case noMatchingKey
        case unsupportedKeyType
    }

}

extension SSHAgent.ResponseType {

    var data: Data {
        var raw = self.rawValue
        return  Data(bytes: &raw, count: UInt8.bitWidth/8)
    }

}
