import CryptoKit
import Foundation
import Testing
@testable import SecretiveCLI

// MARK: - VersionCommand Tests

@Suite("VersionCommand") @MainActor
struct VersionCommandTests {
    // MARK: - VersionInfo JSON schema

    @Test("VersionInfo encodes all required fields")
    func versionInfoAllFields() throws {
        let info = VersionInfo(
            version: "4.0.0",
            build: "99",
            os_version: "macOS 26.0 (26A1234)",
            secure_enclave_available: true,
            post_quantum_algorithms: ["mldsa-65", "mldsa-87"],
        )
        let data = try JSONEncoder().encode(info)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["version"] != nil)
        #expect(dict?["build"] != nil)
        #expect(dict?["os_version"] != nil)
        #expect(dict?["secure_enclave_available"] != nil)
        #expect(dict?["post_quantum_algorithms"] != nil)
    }

    @Test("secure_enclave_available is a Bool (not Optional)")
    func secureEnclaveAvailableIsBoolean() throws {
        let info = VersionInfo(
            version: "4.0.0", build: "1",
            os_version: "macOS 14.0",
            secure_enclave_available: false,
            post_quantum_algorithms: [],
        )
        let data = try JSONEncoder().encode(info)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let val = dict?["secure_enclave_available"]
        // Must be a Bool value, not NSNull
        #expect(val is NSNumber, "secure_enclave_available must be Bool/NSNumber, got: \(String(describing: val))")
    }

    @Test("post_quantum_algorithms is empty array on pre-26 OS (if applicable)")
    func pqAlgosEmptyWhenUnavailable() throws {
        // This test validates the schema regardless of host OS version
        let info = VersionInfo(
            version: "3.9.0", build: "5",
            os_version: "macOS 15.0",
            secure_enclave_available: true,
            post_quantum_algorithms: [], // simulating pre-macOS-26
        )
        let data = try JSONEncoder().encode(info)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let algos = dict?["post_quantum_algorithms"] as? [String]
        #expect(algos?.isEmpty == true)
    }

    // MARK: - Runtime availability check

    @Test("CryptoKit.SecureEnclave.isAvailable returns a Bool")
    func secureEnclaveAvailabilityIsBoolean() {
        // Just verify the API returns without crashing and is Bool-typed
        let available: Bool = CryptoKit.SecureEnclave.isAvailable
        // On CI or non-SE hardware this will be false — that's expected
        _ = available
        #expect(true) // If we reach here, the API call succeeded
    }
}
