import Foundation
import XCTest
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
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestFailure)
    }

    func testSignature() {

    }

    func testEndToEnd() {

    }

    // MARK: Witness protocol

    func testWitnessObjectionStopsRequest() {

    }

    func testWitnessSignature() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let list = storeList(with: [Constants.Secrets.ecdsa256Secret, Constants.Secrets.ecdsa384Secret])
        let agent = Agent(storeList: list)
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestIdentitiesMultiple)
    }

    func testRequestTracing() {

    }

    // MARK: Exception Handling

    func testSignatureException() {

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

    func storeList(with secrets: [SmartCard.Secret]) -> SecretStoreList {
        let store = StubStore()
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
        }

        enum Responses {
            static let requestIdentitiesEmpty = Data(base64Encoded: "AAAABQwAAAAA")!
            static let requestIdentitiesMultiple = Data(base64Encoded: "AAABKwwAAAACAAAAaAAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQTlRI4AAOTx6kYMMpIzeajNtblghxUmP0qqOYJBwJJ/ntTDEChzi4Gu7nAfW95on99zAYnefRkSvRhD1ZTIkkMKAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQAAABNlY2RzYS1zaGEyLW5pc3RwMzg0")!
            static let requestFailure = Data(base64Encoded: "AAAAAQU=")!
        }

        enum Secrets {
            static let ecdsa256Secret =  SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 256)", algorithm: .ellipticCurve, keySize: 256, publicKey: Data(base64Encoded: "BOVEjgAA5PHqRgwykjN5qM21uWCHFSY/Sqo5gkHAkn+e1MMQKHOLga7ucB9b3mif33MBid59GRK9GEPVlMiSQwo=")!)
            static let ecdsa384Secret =  SmartCard.Secret(id: Data(), name: "Test Key (ECDSA 384)", algorithm: .ellipticCurve, keySize: 384, publicKey: Data(base64Encoded: "BG2MNc/C5OTHFE2tBvbZCVcpOGa8vBMquiTLkH4lwkeqOPxhi+PyYUfQZMTRJNPiTyWPoMBqNiCIFRVv60yPN/AHufHaOgbdTP42EgMlMMImkAjYUEv9DESHTVIs2PW1yQ==")!)
        }

    }

}
