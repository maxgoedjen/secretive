import Foundation
import XCTest
import SecretKit
@testable import SecretAgentKit

class AgentTests: XCTestCase {

    func testEmptyStores() {
        let agent = Agent(storeList: SecretStoreList())
    }

    func testRequestTracer() {
        // Request tracer should show for Xcode?
    }

    func testWitnessObjection() {

    }

    func testWitnessSignature() {

    }

    func testIdentitiesList() {

    }

    func testSignature() {

    }

    func testSignatureException() {

    }

    func testUnhandledAdd() {

    }

}
