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

    public func handle(request: SSHAgent.Request, provenance: SigningRequestProvenance) async -> Data {
        // Depending on the launch context (such as after macOS update), the agent may need to reload secrets before acting
        await reloadSecretsIfNeccessary()
        var response = Data()
        do {
            switch request {
            case .requestIdentities:
                response.append(SSHAgent.Response.agentIdentitiesAnswer.data)
                response.append(await identities())
                logger.debug("Agent returned \(SSHAgent.Response.agentIdentitiesAnswer.debugDescription)")
            case .signRequest(let context):
                response.append(SSHAgent.Response.agentSignResponse.data)
                response.append(try await sign(data: context.dataToSign, keyBlob: context.keyBlob, provenance: provenance))
                logger.debug("Agent returned \(SSHAgent.Response.agentSignResponse.debugDescription)")
            default:
                logger.debug("Agent received valid request of type \(request.debugDescription), but not currently supported.")
                throw UnhandledRequestError()
            }
        } catch {
            response = SSHAgent.Response.agentFailure.data
            logger.debug("Agent returned \(SSHAgent.Response.agentFailure.debugDescription)")
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
    func sign(data: Data, keyBlob: Data, provenance: SigningRequestProvenance) async throws -> Data {
        // Check if hash is actually an openssh certificate and reconstruct the public key if it is
        let resolvedBlob: Data
        if let certificatePublicKey = await certificateHandler.publicKeyHash(from: keyBlob) {
            resolvedBlob = certificatePublicKey
        } else {
            resolvedBlob = keyBlob
        }
        
        guard let (secret, store) = await secret(matching: resolvedBlob) else {
            logger.debug("Agent did not have a key matching \(resolvedBlob as NSData)")
            throw NoMatchingKeyError()
        }

        try await witness?.speakNowOrForeverHoldYourPeace(forAccessTo: secret, from: store, by: provenance)

        let rawRepresentation = try await store.sign(data: data, with: secret, for: provenance)
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

    struct NoMatchingKeyError: Error {}
    struct UnhandledRequestError: Error {}

}

extension SSHAgent.Response {

    var data: Data {
        var raw = self.rawValue
        return  Data(bytes: &raw, count: MemoryLayout<UInt8>.size)
    }

}
