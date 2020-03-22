import Foundation
import XCTest
import SecretKit
@testable import SecretAgentKit

class AgentTests: XCTestCase {

    let stubWriter = StubFileHandleWriter()

    // MARK: Identity Listing

    func testEmptyStores() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let agent = Agent(storeList: SecretStoreList())
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssertEqual(stubWriter.data, Constants.Responses.requestIdentities)
    }

    func testIdentitiesList() {

    }

    // MARK: Signatures

    func testWitnessObjectionStopsRequest() {
    }

    func testWitnessSignature() {

    }


    func testNoMatchingIdentities() {

    }

    func testMultipleIdentities() {

    }

    func testSignature() {

    }


    func testRequestTracing() {
        let stubReader = StubFileHandleReader(availableData: Constants.Requests.requestIdentities)
        let agent = Agent(storeList: SecretStoreList())
        agent.handle(reader: stubReader, writer: stubWriter)
        XCTAssert(stubWriter.data == Constants.Requests.requestIdentities)
    }

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

    enum Constants {

        enum Requests {
            static let requestIdentities = Data(base64Encoded: "AAAAAQs=")!
            static let addIdentity = Data(base64Encoded: "AAAAAQs=")!
        }

        enum Responses {
            static let requestIdentities = Data(base64Encoded: "AAAABQwAAAAA")!
            static let requestFailure = Data(base64Encoded: "AAAABQwAAAAA")!
        }
    }

}
