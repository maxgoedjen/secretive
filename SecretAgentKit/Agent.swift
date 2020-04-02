import Foundation
import CryptoKit
import OSLog
import SecretKit
import AppKit

public class Agent {

    fileprivate let storeList: SecretStoreList
    fileprivate let witness: SigningWitness?
    fileprivate let writer = OpenSSHKeyWriter()
    fileprivate let requestTracer = SigningRequestTracer()

    public init(storeList: SecretStoreList, witness: SigningWitness? = nil) {
        os_log(.debug, "Agent is running")
        self.storeList = storeList
        self.witness = witness
    }
    
}

extension Agent {

    public func handle(reader: FileHandleReader, writer: FileHandleWriter) {
        os_log(.debug, "Agent handling new data")
        let data = reader.availableData
        guard !data.isEmpty else { return }
        let requestTypeInt = data[4]
        guard let requestType = SSHAgent.RequestType(rawValue: requestTypeInt) else {
            writer.write(OpenSSHKeyWriter().lengthAndData(of: SSHAgent.ResponseType.agentFailure.data))
            os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentFailure.debugDescription)
            return
        }
        os_log(.debug, "Agent handling request of type %@", requestType.debugDescription)
        let subData = Data(data[5...])
        let response = handle(requestType: requestType, data: subData, reader: reader)
        writer.write(response)
    }

    func handle(requestType: SSHAgent.RequestType, data: Data, reader: FileHandleReader) -> Data {
        var response = Data()
        do {
            switch requestType {
            case .requestIdentities:
                response.append(SSHAgent.ResponseType.agentIdentitiesAnswer.data)
                response.append(identities())
                os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentIdentitiesAnswer.debugDescription)
            case .signRequest:
                let provenance = requestTracer.provenance(from: reader)
                response.append(SSHAgent.ResponseType.agentSignResponse.data)
                response.append(try sign(data: data, provenance: provenance))
                os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentSignResponse.debugDescription)
            }
        } catch {
            response.removeAll()
            response.append(SSHAgent.ResponseType.agentFailure.data)
            os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentFailure.debugDescription)
        }
        let full = OpenSSHKeyWriter().lengthAndData(of: response)
        return full
    }

}

extension Agent {

    func identities() -> Data {
        // TODO: RESTORE ONCE XCODE 11.4 IS GM
        let secrets = storeList.stores.flatMap { $0.secrets }
//        let secrets = storeList.stores.flatMap(\.secrets)
        var count = UInt32(secrets.count).bigEndian
        let countData = Data(bytes: &count, count: UInt32.bitWidth/8)
        var keyData = Data()
        let writer = OpenSSHKeyWriter()
        for secret in secrets {
            let keyBlob = writer.data(secret: secret)
            keyData.append(writer.lengthAndData(of: keyBlob))
            let curveData = writer.curveType(for: secret.algorithm, length: secret.keySize).data(using: .utf8)!
            keyData.append(writer.lengthAndData(of: curveData))
        }
        os_log(.debug, "Agent enumerated %@ identities", secrets.count as NSNumber)
        return countData + keyData
    }

    func sign(data: Data, provenance: SigningRequestProvenance) throws -> Data {
        let reader = OpenSSHReader(data: data)
        let hash = reader.readNextChunk()
        guard let (store, secret) = secret(matching: hash) else {
            os_log(.debug, "Agent did not have a key matching %@", hash as NSData)
            throw AgentError.noMatchingKey
        }

        if let witness = witness {
            try witness.speakNowOrForeverHoldYourPeace(forAccessTo: secret, by: provenance)
        }

        let dataToSign = reader.readNextChunk()
        let derSignature = try store.sign(data: dataToSign, with: secret)

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
            try witness.witness(accessTo: secret, by: provenance)
        }

        os_log(.debug, "Agent signed request")

        return signedData
    }

}

extension Agent {

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
