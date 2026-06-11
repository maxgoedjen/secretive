import Foundation
import CryptoKit
import OSLog
import SecretKit
import CertificateKit
import AppKit
import SSHProtocolKit

/// The `Agent` is an implementation of an SSH agent. It manages coordination and access between a socket, traces requests, notifies witnesses and passes requests to stores.
public final class Agent: Sendable {

    private let storeList: SecretStoreList
    private let authenticationHandler: AuthenticationHandler
    private let certificateStore: CertificateStore
    private let witness: SigningWitness?
    private let publicKeyWriter = OpenSSHPublicKeyWriter()
    private let signatureWriter = OpenSSHSignatureWriter()
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "Agent")

    /// Initializes an agent with a store list and a witness.
    /// - Parameters:
    ///   - storeList: The `SecretStoreList` to make available.
    ///   - witness: A witness to notify of requests.
    public init(
        storeList: SecretStoreList,
        certificateStore: CertificateStore,
        authenticationHandler: AuthenticationHandler,
        witness: SigningWitness? = nil
    ) {
        logger.debug("Agent is running")
        self.storeList = storeList
        self.certificateStore = certificateStore
        self.authenticationHandler = authenticationHandler
        self.witness = witness
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
            case .unknown(let value):
                logger.error("Agent received unknown request of type \(value).")
                throw UnhandledRequestError()
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
        var count = 0
        var keyData = Data()

        for secret in secrets {
            let keyBlob = publicKeyWriter.data(secret: secret)
            keyData.append(keyBlob.lengthAndData)
            keyData.append(publicKeyWriter.comment(secret: secret).lengthAndData)
            count += 1
            for certificate in await certificateStore.certificates(for: secret) {
                keyData.append(certificate.data.lengthAndData)
                keyData.append(certificate.name.lengthAndData)
                count += 1
            }
        }
        logger.log("Agent enumerated \(count) identities")
        var countBigEndian = UInt32(count).bigEndian
        let countData = unsafe Data(bytes: &countBigEndian, count: MemoryLayout<UInt32>.size)
        return countData + keyData
    }

    /// Notifies witnesses of a pending signature request, and performs the signing operation if none object.
    /// - Parameters:
    ///   - data: The data to sign.
    ///   - provenance: A ``SecretKit.SigningRequestProvenance`` object describing the origin of the request.
    /// - Returns: An OpenSSH formatted Data payload containing the signed data response.
    func sign(data: Data, keyBlob: Data, provenance: SigningRequestProvenance) async throws -> Data {
        guard let (secret, store) = await secret(matching: keyBlob) else {
            let keyBlobHex = keyBlob.formatted(.hex())
            logger.debug("Agent did not have a key matching \(keyBlobHex)")
            throw NoMatchingKeyError()
        }

        logger.debug("Agent offering witness chance to object")
        do {
            try await witness?.speakNowOrForeverHoldYourPeace(forAccessTo: secret, from: store, by: provenance)
        } catch {
            logger.debug("Witness objected")
            throw error
        }
        logger.debug("Witness did not object")

        if secret.authenticationRequirement.required {
            // Slow path, may block or suggest batching.
            return try await signWithRequiredAuthentication(data: data, store: store, secret: secret, provenance: provenance)
        } else {
            // Fast path, no blocking/enqueing required
            return try await signWithoutRequiredAuthentication(data: data, store: store, secret: secret, provenance: provenance)
        }
    }

    func signWithoutRequiredAuthentication(data: Data, store: AnySecretStore, secret: AnySecret, provenance: SigningRequestProvenance) async throws -> Data {
        let rawRepresentation = try await store.sign(data: data, with: secret, for: provenance, context: nil)
        let signedData = signatureWriter.data(secret: secret, signature: rawRepresentation)
        try await witness?.witness(accessTo: secret, from: store, by: provenance, offerPersistence: false)
        logger.debug("Agent signed request")
        return signedData
    }

    func signWithRequiredAuthentication(data: Data, store: AnySecretStore, secret: AnySecret, provenance: SigningRequestProvenance) async throws -> Data {
//        let context: any AuthenticationContextProtocol
//        let offerPersistence: Bool
//        if let existing = await authenticationHandler.existingAuthenticationContextProtocol(for: SignatureRequest(secret: secret, provenance: provenance)) {
//            context = existing
//            offerPersistence = false
//            logger.debug("Using existing auth context")
//        } else {
//            context = authenticationHandler.createAuthenticationContext(for: SignatureRequest(secret: secret, provenance: provenance))
//            offerPersistence = secret.authenticationRequirement.required
//            logger.debug("Creating fresh auth context")
//        }



        let context = try await authenticationHandler.waitForAuthentication(for: SignatureRequest(secret: secret, provenance: provenance))
        let result = try await store.sign(data: data, with: secret, for: provenance, context: context.laContext)
        let signedData = signatureWriter.data(secret: secret, signature: result)
        try await witness?.witness(accessTo: secret, from: store, by: provenance, offerPersistence: false) // FIXME: THIS
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
        return unsafe Data(bytes: &raw, count: MemoryLayout<UInt8>.size)
    }

}
