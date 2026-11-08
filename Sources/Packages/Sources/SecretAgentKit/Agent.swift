import Foundation
import CryptoKit
import OSLog
import SecretKit
import CertificateKit
import AppKit
import SSHProtocolKit
import LocalAuthentication

/// The `Agent` is an implementation of an SSH agent. It manages coordination and access between a socket, traces requests, notifies witnesses and passes requests to stores.
public final class Agent: Sendable {

    private let storeList: SecretStoreList
    private let authenticationHandler: AuthenticationHandler
    private let certificateStore: CertificateStore
    private let witness: SigningWitness?
    private let publicKeyWriter = OpenSSHPublicKeyWriter()
    private let signatureWriter = OpenSSHSignatureWriter()
    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent", category: "Agent")

    @MainActor private var sessionID: SSHAgent.ProtocolExtension.OpenSSHExtension.SessionBindContext?

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

    public func handle(
        request: SSHAgent.Request,
        provenance: SigningRequestProvenance,
        hosts: [Data: String]?
    ) async -> Data {
        logger.debug("Agent received request of type \(request.debugDescription)")
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
                let target: SigningRequestTarget?
                switch context.dataToSign.decoded {
                case .sshConnection(let payload):
                    target = .connection(
                        .init(
                            username: payload.username,
                            hasSignature: payload.hasSignature,
                            publicKeyAlgorithm: payload.publicKeyAlgorithm,
                            publicKey: payload.publicKey,
                            hostKey: payload.hostKey,
                            host: hosts?[payload.hostKey]
                        )
                    )
                    if let boundSession = await sessionID {
                        guard payload.hostKey == boundSession.hostKey else {
                            logger.error("Agent received bind request, but host key does not match signature request host key.")
                            throw BindingFailure()
                        }
                    }
                case .sshSig(let payload):
                    target = .signature(
                        .init(
                            namespace: payload.namespace,
                            hashAlgorithm: payload.hashAlgorithm,
                            hash: payload.hash
                        )
                    )
                default:
                    target = nil
                }
                _ = target
                response.append(SSHAgent.Response.agentSignResponse.data)
                response.append(try await sign(data: context.dataToSign.raw, keyBlob: context.keyBlob, provenance: provenance, target: target))
                logger.debug("Agent returned \(SSHAgent.Response.agentSignResponse.debugDescription)")
            case .protocolExtension(.openSSH(.sessionBind(let bind))):
                // This is disabled until forward enforcement is handled.
                _ = bind
                response = try await MainActor.run {
                    logger.debug("Agent received bind request but not currently supported.")
                    throw UnhandledRequestError()
//                    guard sessionID == nil else {
//                        logger.error("Agent received bind request, but already bound.")
//                        throw BindingFailure()
//                    }
//                    logger.debug("Agent bound")
//                    sessionID = bind
//                    return SSHAgent.Response.agentSuccess.data
                }
                logger.debug("Agent returned \(SSHAgent.Response.agentSuccess.debugDescription)")
            case .protocolExtension(.secretive(let secretiveExtension)):
                switch secretiveExtension {
                case .createKey(let context):
                    if let peerUID = provenance.peerUID, peerUID != getuid() {
                        logger.error("Agent: Unauthorized UID \(peerUID) != current UID \(getuid())")
                        throw UnhandledRequestError()
                    }
                    let keyType: KeyType = switch context.keyType.lowercased() {
                    case "ecdsa-256", "ecdsa-sha2-nistp256", "ecdsa": .ecdsa256
                    case "ecdsa-384", "ecdsa-sha2-nistp384": .ecdsa384
                    case "mldsa-65": .mldsa65
                    case "mldsa-87": .mldsa87
                    default: .ecdsa256
                    }
                    let authReq: AuthenticationRequirement = context.requireBiometrics ? .presenceRequired : .notRequired
                    let attrs = Attributes(keyType: keyType, authentication: authReq)
                    guard let modifiableStore = await storeList.modifiableStore else {
                        logger.error("Agent: No modifiable store available.")
                        throw UnhandledRequestError()
                    }
                    let secret = try await modifiableStore.create(name: context.name, attributes: attrs)
                    let pubKeyBlob = publicKeyWriter.data(secret: secret)
                    response.append(SSHAgent.Response.agentSuccess.data)
                    response.append(pubKeyBlob.lengthAndData)
                    logger.debug("Agent successfully created key '\(context.name)' via extension")
                case .deleteKey(let context):
                    if let peerUID = provenance.peerUID, peerUID != getuid() {
                        logger.error("Agent: Unauthorized UID \(peerUID) != current UID \(getuid())")
                        throw UnhandledRequestError()
                    }
                    guard let modifiableStore = await storeList.modifiableStore else {
                        logger.error("Agent: No modifiable store available.")
                        throw UnhandledRequestError()
                    }
                    guard let secret = await modifiableStore.secrets.first(where: { $0.name == context.identifier || $0.id == AnyHashable(context.identifier) }) else {
                        logger.error("Agent: Secret '\(context.identifier)' not found.")
                        throw UnhandledRequestError()
                    }
                    // AAL3 Protection: LocalAuthentication prompt for key destruction
                    let authContext = LAContext()
                    var authError: NSError?
                    let reason = "Delete key \(secret.name)"
                    if unsafe authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
                        let success = try await authContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                        guard success else {
                            logger.error("Agent: Authentication failed for key deletion.")
                            throw UnhandledRequestError()
                        }
                    }
                    try await modifiableStore.delete(secret: secret)
                    response.append(SSHAgent.Response.agentSuccess.data)
                    logger.debug("Agent successfully deleted key '\(context.identifier)' via extension")
                case .renameKey(let context):
                    if let peerUID = provenance.peerUID, peerUID != getuid() {
                        logger.error("Agent: Unauthorized UID \(peerUID) != current UID \(getuid())")
                        throw UnhandledRequestError()
                    }
                    guard let modifiableStore = await storeList.modifiableStore else {
                        logger.error("Agent: No modifiable store available.")
                        throw UnhandledRequestError()
                    }
                    guard let secret = await modifiableStore.secrets.first(where: { $0.name == context.identifier || $0.id == AnyHashable(context.identifier) }) else {
                        logger.error("Agent: Secret '\(context.identifier)' not found.")
                        throw UnhandledRequestError()
                    }
                    let newAttrs = Attributes(
                        keyType: secret.keyType,
                        authentication: secret.authenticationRequirement,
                        publicKeyAttribution: context.attribution ?? secret.attributes.publicKeyAttribution
                    )
                    try await modifiableStore.update(secret: secret, name: context.newName, attributes: newAttrs)
                    response.append(SSHAgent.Response.agentSuccess.data)
                    logger.debug("Agent successfully renamed key '\(context.identifier)' to '\(context.newName)' via extension")
                case .listKeys:
                    let secretsWithStores = await storeList.allSecretsWithStores
                    var items: [KeyListItem] = []
                    for (secret, store) in secretsWithStores {
                        let storeName = await store.name
                        let pubKeyStr = publicKeyWriter.openSSHString(secret: secret)
                        let sha256 = publicKeyWriter.openSSHSHA256Fingerprint(secret: secret)
                        let md5 = publicKeyWriter.openSSHMD5Fingerprint(secret: secret)
                        let minimalHex = md5.replacingOccurrences(of: ":", with: "")
                        let pubKeyPath = "\(minimalHex).pub"
                        items.append(KeyListItem(
                            store: storeName,
                            name: secret.name,
                            algorithm: formatKeyAlgorithm(secret.keyType),
                            authentication: secret.authenticationRequirement.rawValue,
                            fingerprint_sha256: sha256,
                            fingerprint_md5: md5,
                            public_key: pubKeyStr,
                            public_key_path: pubKeyPath
                        ))
                    }
                    let encoded = try JSONEncoder().encode(items)
                    response.append(SSHAgent.Response.agentSuccess.data)
                    response.append(encoded.lengthAndData)
                    logger.debug("Agent returned \(items.count) keys via listKeys extension")
                case .listCerts:
                    let certs = await certificateStore.certificates
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let items = certs.map { cert -> CertListItem in
                        let validUntil: String? = if let range = cert.openSSHCertificate.validityRange {
                            dateFormatter.string(from: range.upperBound)
                        } else {
                            nil
                        }
                        return CertListItem(
                            name: cert.openSSHCertificate.name,
                            key_id: cert.openSSHCertificate.keyID,
                            serial: cert.openSSHCertificate.serial,
                            principals: cert.openSSHCertificate.principals,
                            valid_until: validUntil
                        )
                    }
                    let encoded = try JSONEncoder().encode(items)
                    response.append(SSHAgent.Response.agentSuccess.data)
                    response.append(encoded.lengthAndData)
                    logger.debug("Agent returned \(items.count) certificates via listCerts extension")
                case .importCert(let context):
                    if let peerUID = provenance.peerUID, peerUID != getuid() {
                        logger.error("Agent: Unauthorized UID \(peerUID) != current UID \(getuid())")
                        throw UnhandledRequestError()
                    }
                    let parser = OpenSSHCertificateParser()
                    let parsedCert = try parser.parse(data: context.certificateData)
                    var fullCert = Certificate(openSSHCertificate: parsedCert, rawData: context.certificateData)
                    if let overrideName = context.nameOverride {
                        fullCert.openSSHCertificate.name = overrideName
                    }
                    let importedName = fullCert.openSSHCertificate.name
                    try await MainActor.run {
                        try certificateStore.save(certificate: fullCert)
                    }
                    response.append(SSHAgent.Response.agentSuccess.data)
                    response.append(importedName.lengthAndData)
                    logger.debug("Agent successfully imported certificate '\(importedName)' via extension")
                case .deleteCert(let context):
                    if let peerUID = provenance.peerUID, peerUID != getuid() {
                        logger.error("Agent: Unauthorized UID \(peerUID) != current UID \(getuid())")
                        throw UnhandledRequestError()
                    }
                    let certs = await certificateStore.certificates
                    guard let target = certs.first(where: {
                        $0.openSSHCertificate.name == context.identifier ||
                        $0.openSSHCertificate.keyID == context.identifier ||
                        $0.id == context.identifier
                    }) else {
                        logger.error("Agent: Certificate '\(context.identifier)' not found.")
                        throw UnhandledRequestError()
                    }
                    let deletedName = target.openSSHCertificate.name
                    try await MainActor.run {
                        try certificateStore.delete(certificate: target)
                    }
                    response.append(SSHAgent.Response.agentSuccess.data)
                    logger.debug("Agent successfully deleted certificate '\(deletedName)' via extension")
                case .unknown(let name):
                    logger.error("Agent received unknown Secretive extension '\(name)'.")
                    throw UnhandledRequestError()
                }
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
    func sign(data: Data, keyBlob: Data, provenance: SigningRequestProvenance, target: SigningRequestTarget?) async throws -> Data {
        guard let (secret, store) = await secret(matching: keyBlob) else {
            let keyBlobHex = keyBlob.formatted(.hex())
            logger.debug("Agent did not have a key matching \(keyBlobHex)")
            throw NoMatchingKeyError()
        }
        logger.debug("Agent offering witness chance to object")
        do {
            try await witness?.speakNowOrForeverHoldYourPeace(forAccessTo: secret, from: store, by: provenance, target: target)
        } catch {
            logger.debug("Witness objected")
            throw error
        }
        logger.debug("Witness did not object")

        let request = SignatureRequest(secret: secret, provenance: provenance, target: target)
        let newContext = AuthenticationContext(secret: secret, requests: [request])
        let context = try await authenticationHandler.authenticatedContext(for: request, context: newContext)
        let result = try await store.sign(data: data, with: secret, for: provenance, target: target, context: context?.laContext)
        let signedData = signatureWriter.data(secret: secret, signature: result)
        try await witness?.witness(accessTo: secret, from: store, by: provenance, target: target, offerPersistence: secret.authenticationRequirement.required)
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

    private func formatKeyAlgorithm(_ keyType: KeyType) -> String {
        switch keyType {
        case .ecdsa256: "ecdsa-sha2-nistp256"
        case .ecdsa384: "ecdsa-sha2-nistp384"
        case .mldsa65: "mldsa-65"
        case .mldsa87: "mldsa-87"
        case .rsa2048: "rsa-2048"
        default: keyType.description
        }
    }

}


extension Agent {

    struct NoMatchingKeyError: Error {}
    struct UnhandledRequestError: Error {}
    struct BindingFailure: Error {}

}

extension SSHAgent.Response {

    var data: Data {
        var raw = self.rawValue
        return unsafe Data(bytes: &raw, count: MemoryLayout<UInt8>.size)
    }

}
