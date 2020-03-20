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

    public func handle(fileHandle: FileHandle) {
        os_log(.debug, "Agent handling new data")
        let data = fileHandle.availableData
        guard !data.isEmpty else { return }
        let requestTypeInt = data[4]
        guard let requestType = SSHAgent.RequestType(rawValue: requestTypeInt) else { return }
        os_log(.debug, "Agent handling request of type %@", requestType.debugDescription)
        let subData = Data(data[5...])
        handle(requestType: requestType, data: subData, fileHandle: fileHandle)
    }

    func handle(requestType: SSHAgent.RequestType, data: Data, fileHandle: FileHandle) {
        var response = Data()
        do {
            switch requestType {
            case .requestIdentities:
                response.append(SSHAgent.ResponseType.agentIdentitiesAnswer.data)
                response.append(try identities())
                os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentIdentitiesAnswer.debugDescription)
            case .signRequest:
                response.append(SSHAgent.ResponseType.agentSignResponse.data)
                response.append(try sign(data: data, from: fileHandle.fileDescriptor))
                os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentSignResponse.debugDescription)
            }
        } catch {
            response.removeAll()
            response.append(SSHAgent.ResponseType.agentFailure.data)
            os_log(.debug, "Agent returned %@", SSHAgent.ResponseType.agentFailure.debugDescription)
        }
        let full = OpenSSHKeyWriter().lengthAndData(of: response)
        fileHandle.write(full)
    }

}

extension Agent {

    func identities() throws -> Data {
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

    func sign(data: Data, from pid: Int32) throws -> Data {
        let reader = OpenSSHReader(data: data)
        let hash = try reader.readNextChunk()
        guard let (store, secret) = secret(matching: hash) else {
            os_log(.debug, "Agent did not have a key matching %@", hash as NSData)
            throw AgentError.noMatchingKey
        }

        let provenance = requestTracer.provenance(from: pid)
        if let witness = witness {
            try witness.speakNowOrForeverHoldYourPeace(forAccessTo: secret, by: provenance)
        }

        let dataToSign = try reader.readNextChunk()
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
            fatalError()
        }


        let rawLength = rawRepresentation.count/2
        let r = rawRepresentation[0..<rawLength]
        let s = rawRepresentation[rawLength...]

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
    }

}

extension SSHAgent.ResponseType {

    var data: Data {
        var raw = self.rawValue
        return  Data(bytes: &raw, count: UInt8.bitWidth/8)
    }

}
