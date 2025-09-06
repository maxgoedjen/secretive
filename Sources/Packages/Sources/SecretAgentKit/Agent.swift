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
    ///   - data: The data to handle.
    ///   - provenance: The origin of the request.
    /// - Returns: A response data payload.
    public func handle(data: Data, provenance: SigningRequestProvenance) async throws -> Data {
        logger.debug("Agent handling new data")
        guard data.count > 4 else {
            throw InvalidDataProvidedError()
        }
        let requestTypeInt = data[4]
        guard let requestType = SSHAgent.RequestType(rawValue: requestTypeInt) else {
            logger.debug("Agent returned \(SSHAgent.ResponseType.agentFailure.debugDescription) for unknown request type \(requestTypeInt)")
            return SSHAgent.ResponseType.agentFailure.data.lengthAndData
        }
        logger.debug("Agent handling request of type \(requestType.debugDescription)")
        let subData = Data(data[5...])
        let response = await handle(requestType: requestType, data: subData, provenance: provenance)
        return response
    }

    private func handle(requestType: SSHAgent.RequestType, data: Data, provenance: SigningRequestProvenance) async -> Data {
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
                response.append(SSHAgent.ResponseType.agentSignResponse.data)
                response.append(try await sign(data: data, provenance: provenance))
                logger.debug("Agent returned \(SSHAgent.ResponseType.agentSignResponse.debugDescription)")
            default:
                logger.debug("Agent received valid request of type \(requestType.debugDescription), but not currently supported.")
                response.append(SSHAgent.ResponseType.agentFailure.data)

            }
        } catch {
            response = SSHAgent.ResponseType.agentFailure.data
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
        var count = 0
        var keyData = Data()

        for secret in secrets {
            let keyBlob = publicKeyWriter.data(secret: secret)
            keyData.append(keyBlob.lengthAndData)
            keyData.append(publicKeyWriter.comment(secret: secret).lengthAndData)
            count += 1

            if let (certificateData, name) = try? await certificateHandler.keyBlobAndName(for: secret) {
                keyData.append(certificateData.lengthAndData)
                keyData.append(name.lengthAndData)
                count += 1
            }
        }
        logger.log("Agent enumerated \(count) identities")
        var countBigEndian = UInt32(count).bigEndian
        let countData = Data(bytes: &countBigEndian, count: MemoryLayout<UInt32>.size)
        return countData + keyData
    }

    /// Notifies witnesses of a pending signature request, and performs the signing operation if none object.
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - provenance: A ``SecretKit.SigningRequestProvenance`` object describing the origin of the request.
    /// - Returns: An OpenSSH formatted Data payload containing the signed data response.
    func sign(data: Data, provenance: SigningRequestProvenance) async throws -> Data {
        let reader = OpenSSHReader(data: data)
        let payloadHash = try reader.readNextChunk()
        let hash: Data

        // Check if hash is actually an openssh certificate and reconstruct the public key if it is
        if let certificatePublicKey = await certificateHandler.publicKeyHash(from: payloadHash) {
            hash = certificatePublicKey
        } else {
            hash = payloadHash
        }
        
        guard let (secret, store) = await secret(matching: hash) else {
            logger.debug("Agent did not have a key matching \(hash as NSData)")
            throw NoMatchingKeyError()
        }

        try await witness?.speakNowOrForeverHoldYourPeace(forAccessTo: secret, from: store, by: provenance)

        let dataToSign = try reader.readNextChunk()
        let rawRepresentation = try await store.sign(data: dataToSign, with: secret, for: provenance)
        let signedData = signatureWriter.data(secret: secret, signature: rawRepresentation)

        try await witness?.witness(accessTo: secret, from: store, by: provenance)

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
    func secret(matching hash: Data) async -> (AnySecret, AnySecretStore)? {
        await storeList.allSecretsWithStores.first {
            hash == publicKeyWriter.data(secret: $0.0)
        }
    }

}


extension Agent {

    struct InvalidDataProvidedError: Error {}
    struct NoMatchingKeyError: Error {}

}

extension SSHAgent.ResponseType {

    var data: Data {
        var raw = self.rawValue
        return  Data(bytes: &raw, count: UInt8.bitWidth/8)
    }

}
