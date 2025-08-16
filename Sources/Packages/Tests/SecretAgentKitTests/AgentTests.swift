import Foundation
import Testing
import CryptoKit
@testable import SecretKit
@testable import SecretAgentKit

@Suite struct AgentTests {

    let stubWriter = StubFileHandleWriter()

    // MARK: Identity Listing

    @Test func emptyStores() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let agent = Agent(storeList: SecretStoreList())
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(stubWriter.data == Constants.Responses.requestIdentitiesEmpty)
    }

    @Test func identitiesList() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(stubWriter.data == Constants.Responses.requestIdentitiesMultiple)
    }

    // MARK: Signatures

    @Test func noMatchingIdentities() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignatureWithNoneMatching)
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(stubWriter.data == Constants.Responses.requestFailure)
    }

    @Test func signature() async throws {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let requestReader = OpenSSHReader(data: Constants.Requests.requestSignature[5...])
        _ = requestReader.readNextChunk()
        let dataToSign = requestReader.readNextChunk()
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
        await agent.handle(reader: stubReader, writer: stubWriter)
        let outer = OpenSSHReader(data: stubWriter.data[5...])
        let payload = outer.readNextChunk()
        let inner = OpenSSHReader(data: payload)
        _ = inner.readNextChunk()
        let signedData = inner.readNextChunk()
        let rsData = OpenSSHReader(data: signedData)
        var r = rsData.readNextChunk()
        var s = rsData.readNextChunk()
        // This is fine IRL, but it freaks out CryptoKit
        if r[0] == 0 {
            r.removeFirst()
        }
        if s[0] == 0 {
            s.removeFirst()
        }
        var rs = r
        rs.append(s)
        let signature = try! P256.Signing.ECDSASignature(rawRepresentation: rs)
        let referenceValid = try! P256.Signing.PublicKey(x963Representation: Constants.Secrets.ecdsa256Secret.publicKey).isValidSignature(signature, for: dataToSign)
        let store = await list.stores.first!
        let derVerifies = try await store.verify(signature: signature.derRepresentation, for: dataToSign, with: AnySecret(Constants.Secrets.ecdsa256Secret))
        let invalidRandomSignature = try await store.verify(signature: "invalid".data(using: .utf8)!, for: dataToSign, with: AnySecret(Constants.Secrets.ecdsa256Secret))
        let invalidRandomData = try await store.verify(signature: signature.derRepresentation, for: "invalid".data(using: .utf8)!, with: AnySecret(Constants.Secrets.ecdsa256Secret))
        let invalidWrongKey = try await store.verify(signature: signature.derRepresentation, for: dataToSign, with: AnySecret(Constants.Secrets.ecdsa384Secret))
        #expect(referenceValid)
        #expect(derVerifies)
        #expect(invalidRandomSignature == false)
        #expect(invalidRandomData == false)
        #expect(invalidWrongKey == false)
    }

    // MARK: Witness protocol

    @Test func witnessObjectionStopsRequest() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret])
        let witness = StubWitness(speakNow: { _,_  in
            return true
        }, witness: { _, _ in })
        let agent = Agent(storeList: list, witness: witness)
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(stubWriter.data == Constants.Responses.requestFailure)
    }

    @Test func witnessSignature() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret])
        nonisolated(unsafe) var witnessed = false
        let witness = StubWitness(speakNow: { _, trace  in
            return false
        }, witness: { _, trace in
            witnessed = true
        })
        let agent = Agent(storeList: list, witness: witness)
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(witnessed)
    }

    @Test func requestTracing() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret])
        nonisolated(unsafe) var speakNowTrace: SigningRequestProvenance?
        nonisolated(unsafe) var witnessTrace: SigningRequestProvenance?
        let witness = StubWitness(speakNow: { _, trace  in
            speakNowTrace = trace
            return false
        }, witness: { _, trace in
            witnessTrace = trace
        })
        let agent = Agent(storeList: list, witness: witness)
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(witnessTrace == speakNowTrace)
        #expect(witnessTrace?.origin.displayName == "Finder")
        #expect(witnessTrace?.origin.validSignature == true)
        #expect(witnessTrace?.origin.parentPID == 1)
    }

    // MARK: Exception Handling

    @Test func signatureException() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = await storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let store = await list.stores.first?.base as! Stub.Store
        store.shouldThrow = true
        let agent = Agent(storeList: list)
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(stubWriter.data == Constants.Responses.requestFailure)
    }

    // MARK: Unsupported

    @Test func unhandledAdd() async {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.addIdentity)
        let agent = Agent(storeList: SecretStoreList())
        await agent.handle(reader: stubReader, writer: stubWriter)
        #expect(stubWriter.data == Constants.Responses.requestFailure)
    }

}

extension AgentTests {

    @MainActor func storeList(with secrets: [Stub.Secret]) async -> SecretStoreList {
        let store = Stub.Store()
        store.secrets.append(contentsOf: secrets)
        let storeList = SecretStoreList()
        storeList.add(store: store)
        return storeList
    }

    enum Constants {

        enum Requests {
            static let requestIdentities = Data(base64Encoded: "AAAAAQs=")!
            static let addIdentity = Data(base64Encoded: "AAAAARE=")!
            static let requestSignatureWithNoneMatching = Data(base64Encoded: "AAABhA0AAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEqCbkJbOHy5S1wVCaJoKPmpS0egM4frMqllgnlRRQ/Uvnn6EVS8oV03cPA2Bz0EdESyRKA/sbmn0aBtgjIwGELxu45UXEW1TEz6TxyS0u3vuIqR3Wo1CrQWRDnkrG/pBQAAAO8AAAAgbqmrqPUtJ8mmrtaSVexjMYyXWNqjHSnoto7zgv86xvcyAAAAA2dpdAAAAA5zc2gtY29ubmVjdGlvbgAAAAlwdWJsaWNrZXkBAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEqCbkJbOHy5S1wVCaJoKPmpS0egM4frMqllgnlRRQ/Uvnn6EVS8oV03cPA2Bz0EdESyRKA/sbmn0aBtgjIwGELxu45UXEW1TEz6TxyS0u3vuIqR3Wo1CrQWRDnkrG/pBQAAAAA=")!
            static let requestSignature = Data(base64Encoded: "AAABRA0AAABoAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy08AAADPAAAAIBIFsbCZ4/dhBmLNGHm0GKj7EJ4N8k/jXRxlyg+LFIYzMgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAAaAAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQSszpFIlSRHAAjLQHfV+8WpW3NBWGcoW5r9nbFpeCD9hliIvkXLGh0DcPpwCEPAihGJi55dFSw6eRH/CjIYCMtPAAAAAA==")!
        }

        enum Responses {
            static let requestIdentitiesEmpty = Data(base64Encoded: "AAAABQwAAAAA")!
            static let requestIdentitiesMultiple = Data(base64Encoded: "AAABKwwAAAACAAAAaAAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQSszpFIlSRHAAjLQHfV+8WpW3NBWGcoW5r9nbFpeCD9hliIvkXLGh0DcPpwCEPAihGJi55dFSw6eRH/CjIYCMtPAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0")!
            static let requestFailure = Data(base64Encoded: "AAAAAQU=")!
        }

        enum Secrets {
            static let ecdsa256Secret =  Stub.Secret(keySize: 256, publicKey: Data(base64Encoded: "BKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy08=")!, privateKey: Data(base64Encoded: "BKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy09nw780wy/TSfUmzj15iJkV234AaCLNl+H8qFL6qK8VIg==")!)
            static let ecdsa384Secret =  Stub.Secret(keySize: 384, publicKey: Data(base64Encoded: "BLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDA==")!, privateKey: Data(base64Encoded: "BLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDHNapAOzrt9E+9QC4/KYoXS7Uw4pmdAz53uIj02tttiq3c0ZyIQ7XoscWWRqRrz8Kw==")!)
        }

    }

}
