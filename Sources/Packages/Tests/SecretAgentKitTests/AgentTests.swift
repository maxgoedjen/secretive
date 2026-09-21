import Foundation
import Testing
import CryptoKit
import CertificateKit
@testable import SSHProtocolKit
@testable import SecretKit
@testable import SecretAgentKit

@Suite @MainActor struct AgentTests {

    // MARK: Identity Listing

    @Test func emptyStores() async throws {
        let agent = Agent(storeList: SecretStoreList(), certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler())
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestIdentities)
        let response = await agent.handle(request: request, provenance: .test, hosts: nil)
        #expect(response == Constants.Responses.requestIdentitiesEmpty)
    }

    @Test func identitiesList() async throws {
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler())
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestIdentities)
        let response = await agent.handle(request: request, provenance: .test, hosts: nil)

        let actual = OpenSSHReader(data: response)
        let expected = OpenSSHReader(data: Constants.Responses.requestIdentitiesMultiple)
        print(actual, expected)
        #expect(response == Constants.Responses.requestIdentitiesMultiple)
    }

    // MARK: Signatures

    @Test func noMatchingIdentities() async throws {
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler())
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestSignatureWithNoneMatching)
        let response = await agent.handle(request: request, provenance: .test, hosts: nil)
        #expect(response == Constants.Responses.requestFailure)
    }

    @Test func ecdsaSignature() async throws {
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestSignature)
        guard case SSHAgent.Request.signRequest(let context) = request else { return }
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler())
        let response = await agent.handle(request: request, provenance: .test, hosts: nil)
        let responseReader = OpenSSHReader(data: response)
        let length = try responseReader.readNextBytes(as: UInt32.self)
        let type = try responseReader.readNextBytes(as: UInt8.self)
        #expect(length == response.count - MemoryLayout<UInt32>.size)
        #expect(type == SSHAgent.Response.agentSignResponse.rawValue)
        let outer = OpenSSHReader(data: responseReader.remaining)
        let inner = try outer.readNextChunkAsSubReader()
        _ = try inner.readNextChunk()
        let rsData = try inner.readNextChunkAsSubReader()
        var r = try rsData.readNextChunk()
        var s = try rsData.readNextChunk()
        // This is fine IRL, but it freaks out CryptoKit
        if r[0] == 0 {
            r.removeFirst()
        }
        if s[0] == 0 {
            s.removeFirst()
        }
        var rs = r
        rs.append(s)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: rs)
        // Correct signature
        #expect(try P256.Signing.PublicKey(x963Representation: Constants.Secrets.ecdsa256Secret.publicKey)
            .isValidSignature(signature, for: context.dataToSign.raw))
    }

    // MARK: Witness protocol

    @Test func witnessObjectionStopsRequest() async throws {
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret])
        let witness = StubWitness(speakNow: { _,_  in
            return true
        }, witness: { _, _ in })
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler(), witness: witness)
        let response = await agent.handle(request: .signRequest(.empty), provenance: .test, hosts: nil)
        #expect(response == Constants.Responses.requestFailure)
    }

    @Test func witnessSignature() async throws {
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret])
        nonisolated(unsafe) var witnessed = false
        let witness = StubWitness(speakNow: { _, trace  in
            return false
        }, witness: { _, trace in
            witnessed = true
        })
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler(), witness: witness)
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestSignature)
        _ = await agent.handle(request: request, provenance: .test, hosts: nil)
        #expect(witnessed)
    }

    @Test func requestTracing() async throws {
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret])
        nonisolated(unsafe) var speakNowTrace: SigningRequestProvenance?
        nonisolated(unsafe) var witnessTrace: SigningRequestProvenance?
        let witness = StubWitness(speakNow: { _, trace  in
            speakNowTrace = trace
            return false
        }, witness: { _, trace in
            witnessTrace = trace
        })
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler(), witness: witness)
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestSignature)
        _ = await agent.handle(request: request, provenance: .test, hosts: nil)
        #expect(witnessTrace == speakNowTrace)
        #expect(witnessTrace == .test)
    }

    // MARK: Exception Handling

    @Test func signatureException() async throws {
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let store = list.stores.first?.base as! Stub.Store
        store.shouldThrow = true
        let agent = Agent(storeList: list, certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler())
        let request = try SSHAgentInputParser().parse(data: Constants.Requests.requestSignature)
        let response = await agent.handle(request: request, provenance: .test, hosts: nil)
        #expect(response == Constants.Responses.requestFailure)
    }

    // MARK: Unsupported

    @Test func unhandledAdd() async throws {
        let agent = Agent(storeList: SecretStoreList(), certificateStore: CertificateStore(), authenticationHandler: AuthenticationHandler())
        let response = await agent.handle(request: .addIdentity, provenance: .test, hosts: nil)
        #expect(response == Constants.Responses.requestFailure)
    }

}
