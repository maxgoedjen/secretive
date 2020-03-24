import Foundation
import XCTest
import CryptoKit
@testable import SecretKit
@testable import SecretAgentKit

class AgentTests: XCTestCase {

    let stubWriter = StubFileHandleWriter()

    // MARK: Identity Listing

    func testEmptyStores() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let agent = Agent(storeList: SecretStoreList())
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestIdentitiesEmpty)
    }

    func testIdentitiesList() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestIdentitiesMultiple)
    }

    // MARK: Signatures

    func testNoMatchingIdentities() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignatureWithNoneMatching)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
//        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestFailure)
    }

    func testSignature() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let requestReader = OpenSSHReader(data: Constants.Requests.requestSignature[5...])
        _ = requestReader.readNextChunk()
        let dataToSign = requestReader.readNextChunk()
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
        agent.handle(reader: stubReader, writer: stubWriter)
        let outer = OpenSSHReader(data: stubWriter.data[5...])
        let payload = outer.readNextChunk()
        let inner = OpenSSHReader(data: payload)
        _ = inner.readNextChunk()
        let signedData = inner.readNextChunk()
        let rsData = OpenSSHReader(data: signedData)
        let r = rsData.readNextChunk()
        let s = rsData.readNextChunk()
        var rs = r
        rs.append(s)
        let signature = try! P256.Signing.ECDSASignature(rawRepresentation: rs)
        let valid = try! P256.Signing.PublicKey(x963Representation: Constants.Secrets.ecdsa256Secret.publicKey).isValidSignature(signature, for: dataToSign)
        XCTAssertTrue(valid)
    }

    // MARK: Witness protocol

    func testWitnessObjectionStopsRequest() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret])
        let witness = StubWitness(speakNow: { _,_  in
            return true
        }, witness: { _, _ in })
        let agent = Agent(storeList: list, witness: witness)
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestFailure)
    }

    func testWitnessSignature() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret])
        var witnessed = false
        let witness = StubWitness(speakNow: { _, trace  in
            return false
        }, witness: { _, trace in
            witnessed = true
        })
        let agent = Agent(storeList: list, witness: witness)
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertTrue(witnessed)
    }

    func testRequestTracing() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret])
        var speakNowTrace: SigningRequestProvenance! = nil
        var witnessTrace: SigningRequestProvenance! = nil
        let witness = StubWitness(speakNow: { _, trace  in
            speakNowTrace = trace
            return false
        }, witness: { _, trace in
            witnessTrace = trace
        })
        let agent = Agent(storeList: list, witness: witness)
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(witnessTrace, speakNowTrace)
        XCTAssertEqual(witnessTrace.origin.name, "Xcode")
        XCTAssertEqual(witnessTrace.origin.validSignature, true)
        XCTAssertEqual(witnessTrace.origin.parentPID, 1)
    }

    // MARK: Exception Handling

    func testSignatureException() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestSignature)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let store = list.stores.first?.base as! Stub.Store
        store.shouldThrow = true
        let agent = Agent(storeList: list)
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestFailure)
    }

    // MARK: Unsupported

    func testUnhandledAdd() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.addIdentity)
        let agent = Agent(storeList: SecretStoreList())
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestFailure)
    }

}

extension AgentTests {

    func storeList(with secrets: [Stub.Secret]) -> SecretStoreList {
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
