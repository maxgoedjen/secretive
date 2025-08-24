import Foundation
import CryptoKit
import OSLog
import SecretKit
import AppKit

/// The `Agent` is an implementation of an SSH agent. It manages coordination and access between a socket, traces requests, notifies witnesses and passes requests to stores.
public final class Agent: Sendable {

    private let storeList: SecretStoreList
    private let witness: SigningWitness?
    private let publicKeyWriter = OpenSSHPublicKeyWriter()
    private let signatureWriter = OpenSSHSignatureWriter()
    private let requestTracer = SigningRequestTracer()
    private let certificateHandler = OpenSSHCertificateHandler()
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "Agent")

    /// Initializes an agent with a store list and a witness.
    /// - Parameters:
    ///   - storeList: The `SecretStoreList` to make available.
    ///   - witness: A witness to notify of requests.
    public init(storeList: SecretStoreList, witness: SigningWitness? = nil) {
        logger.debug("Agent is running")
        self.storeList = storeList
        self.witness = witness
        Task { @MainActor in
            await certificateHandler.reloadCertificates(for: storeList.allSecrets)
        }
    }
    
}

extension Agent {

    /// Handles an incoming request.
    /// - Parameters:
    ///   - reader: A ``FileHandleReader`` to read the content of the request.
    ///   - writer: A ``FileHandleWriter`` to write the response to.
    /// - Return value: 
    ///   - Boolean if data could be read
    @discardableResult public func handle(reader: FileHandleReader, writer: FileHandleWriter) async -> Bool {
        logger.debug("Agent handling new data")
        let data = Data(reader.availableData)
        guard data.count > 4 else { return false}
        let requestTypeInt = data[4]
        guard let requestType = SSHAgent.RequestType(rawValue: requestTypeInt) else {
            writer.write(SSHAgent.ResponseType.agentFailure.data.lengthAndData)
            logger.debug("Agent returned \(SSHAgent.ResponseType.agentFailure.debugDescription)")
            return true
        }
        logger.debug("Agent handling request of type \(requestType.debugDescription)")
        let subData = Data(data[5...])
        let response = await handle(requestType: requestType, data: subData, reader: reader)
        writer.write(response)
        return true
    }

    func handle(requestType: SSHAgent.RequestType, data: Data, reader: FileHandleReader) async -> Data {
        // Depending on the launch context (such as after macOS update), the agent may need to reload secrets before acting
        await reloadSecretsIfNeccessary()
        var response = Data()
        do {
            switch requestType {
            case .requestIdentities:
                response.append(SSHAgent.ResponseType.agentIdentitiesAnswer.data)
                response.append(await identities())
                logger.debug("Agent returned \(SSHAgent.ResponseType.agentIdentitiesAnswer.debugDescription)")
            case .signRequest:
                let provenance = requestTracer.provenance(from: reader)
                response.append(SSHAgent.ResponseType.agentSignResponse.data)
                response.append(try await sign(data: data, provenance: provenance))
                logger.debug("Agent returned \(SSHAgent.ResponseType.agentSignResponse.debugDescription)")
            }
        } catch {
            response.removeAll()
            response.append(SSHAgent.ResponseType.agentFailure.data)
            logger.debug("Agent returned \(SSHAgent.ResponseType.agentFailure.debugDescription)")
        }
        return response.lengthAndData
    }

}

extension Agent {

    /// Lists the identities available for signing operations
    /// - Returns: An OpenSSH formatted Data payload listing the identities available for signing operations.
    func identities() async -> Data {
        let secrets = await storeList.allSecrets
        await certificateHandler.reloadCertificates(for: secrets)
        var count = secrets.count
        var keyData = Data()

        for secret in secrets {
            let keyBlob = publicKeyWriter.data(secret: secret)
            let curveData = publicKeyWriter.openSSHIdentifier(for: secret.keyType)
            keyData.append(keyBlob.lengthAndData)
            keyData.append(curveData.lengthAndData)

            if let (certificateData, name) = try? await certificateHandler.keyBlobAndName(for: secret) {
                keyData.append(certificateData.lengthAndData)
                keyData.append(name.lengthAndData)
                count += 1
            }
        }
        logger.log("Agent enumerated \(count) identities")
        var countBigEndian = UInt32(count).bigEndian
        let countData = Data(bytes: &countBigEndian, count: UInt32.bitWidth/8)
        return countData + keyData
    }

    /// Notifies witnesses of a pending signature request, and performs the signing operation if none object.
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - provenance: A ``SecretKit.SigningRequestProvenance`` object describing the origin of the request.
    /// - Returns: An OpenSSH formatted Data payload containing the signed data response.
    func sign(data: Data, provenance: SigningRequestProvenance) async throws -> Data {
        let reader = OpenSSHReader(data: data)
        let payloadHash = reader.readNextChunk()
        let hash: Data
        // Check if hash is actually an openssh certificate and reconstruct the public key if it is
        if let certificatePublicKey = await certificateHandler.publicKeyHash(from: payloadHash) {
            hash = certificatePublicKey
        } else {
            hash = payloadHash
        }
        
        guard let (store, secret) = await secret(matching: hash) else {
            logger.debug("Agent did not have a key matching \(hash as NSData)")
            throw AgentError.noMatchingKey
        }

        if let witness = witness {
            try await witness.speakNowOrForeverHoldYourPeace(forAccessTo: secret, from: store, by: provenance)
        }

        let dataToSign = reader.readNextChunk()
        let rawRepresentation = try await store.sign(data: dataToSign, with: secret, for: provenance)
        let signedData = signatureWriter.data(secret: secret, signature: rawRepresentation)

        if let witness = witness {
            try await witness.witness(accessTo: secret, from: store, by: provenance)
        }

        logger.debug("Agent signed request")

        return signedData
    }

}

extension Agent {

    /// Gives any store with no loaded secrets a chance to reload.
    func reloadSecretsIfNeccessary() async {
        for store in await storeList.stores {
            if await store.secrets.isEmpty {
                let name = await store.name
                logger.debug("Store \(name, privacy: .public) has no loaded secrets. Reloading.")
                await store.reloadSecrets()
            }
        }
    }

    /// Finds a ``Secret`` matching a specified hash whos signature was requested.
    /// - Parameter hash: The hash to match against.
    /// - Returns: A ``Secret`` and the ``SecretStore`` containing it, if a match is found.
    func secret(matching hash: Data) async -> (AnySecretStore, AnySecret)? {
        for store in await storeList.stores {
            let allMatching = await store.secrets.filter { secret in
                hash == publicKeyWriter.data(secret: secret)
            }
            if let matching = allMatching.first {
                return (store, matching)
            }
        }
        return nil
    }

}


extension Agent {

    /// An error involving agent operations..
    enum AgentError: Error {
        case unhandledType
        case noMatchingKey
        case unsupportedKeyType
        case notOpenSSHCertificate
    }

}

extension SSHAgent.ResponseType {

    var data: Data {
        var raw = self.rawValue
        return  Data(bytes: &raw, count: UInt8.bitWidth/8)
    }

}
