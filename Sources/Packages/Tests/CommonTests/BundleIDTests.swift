import XCTest
@testable import Common

final class BundleIDTests: XCTestCase {

    func testReplacingLastBundleComponentRewritesHostBundleIDs() {
        XCTAssertEqual(
            Bundle.replacingLastBundleComponent(
                in: "2DC432GLL2.com.example.Secretive.Host",
                with: "SecretAgent"
            ),
            "2DC432GLL2.com.example.Secretive.SecretAgent"
        )
    }

    func testReplacingLastBundleComponentRewritesAgentBundleIDsForXPCServices() {
        XCTAssertEqual(
            Bundle.replacingLastBundleComponent(
                in: "2DC432GLL2.com.example.Secretive.SecretAgent",
                with: "SecretAgentInputParser"
            ),
            "2DC432GLL2.com.example.Secretive.SecretAgentInputParser"
        )
    }

    func testReplacingLastBundleComponentRewritesBetweenXPCServices() {
        XCTAssertEqual(
            Bundle.replacingLastBundleComponent(
                in: "2DC432GLL2.com.example.Secretive.SecretiveUpdater",
                with: "SecretAgentInputParser"
            ),
            "2DC432GLL2.com.example.Secretive.SecretAgentInputParser"
        )
    }
}
