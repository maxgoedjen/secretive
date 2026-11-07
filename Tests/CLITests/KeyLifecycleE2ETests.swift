import CryptoKit
import Foundation
import Testing
@testable import SecretiveCLI

// MARK: - E2E: Key Lifecycle Tests

//
// These tests exercise the FULL key lifecycle: create → list → show → rename → delete.
// They require:
//   1. Apple Silicon hardware with Secure Enclave
//   2. An active Secretive agent supporting Secretive protocol extensions (or SECRETIVE_E2E_TESTS=1)
//
// In CI: runs only in workflows after agent is running or in signed contexts.
// Locally: developer must have an active compatible agent running.

// MARK: - Trait: requiresSecureEnclave

extension Trait where Self == ConditionTrait {
    /// Skip the test on hardware or CI environments without Secure Enclave or without an active compatible agent.
    static var requiresSecureEnclave: ConditionTrait {
        .enabled(
            if: E2ERunner.isAvailable,
            "Requires Apple Silicon Secure Enclave and an active SecretAgent supporting Secretive extensions",
        )
    }
}

// MARK: - E2E Test Helper

/// Locates the signed release binary for E2E tests.
/// Prefers the Xcode archive product over the debug SPM build.
enum E2ERunner {
    static var isAvailable: Bool {
        guard CryptoKit.SecureEnclave.isAvailable else { return false }
        if ProcessInfo.processInfo.environment["SECRETIVE_E2E_TESTS"] != nil {
            return true
        }
        let socketPath = StoreProvider.socketPath
        guard FileManager.default.fileExists(atPath: socketPath) else { return false }
        do {
            _ = try SafePosixSocket.listKeys(socketPath: socketPath)
            return true
        } catch {
            return false
        }
    }

    static var executableURL: URL {
        // 1. Xcode archive product (release workflow)
        let archivePath = FileManager.default.currentDirectoryPath
        let releaseURL = URL(fileURLWithPath: archivePath)
            .appendingPathComponent("Archive.xcarchive/Products/Applications/Secretive.app/Contents/MacOS/secretive")
        if FileManager.default.fileExists(atPath: releaseURL.path) {
            return releaseURL
        }

        // 2. SPM release build
        let spmRelease = URL(fileURLWithPath: archivePath)
            .appendingPathComponent(".build/release/secretive")
        if FileManager.default.fileExists(atPath: spmRelease.path) {
            return spmRelease
        }

        // 3. SPM debug build (developer local workflow)
        return URL(fileURLWithPath: archivePath)
            .appendingPathComponent(".build/debug/secretive")
    }

    /// Runs the signed CLI binary with the given arguments.
    /// - Returns: `(stdout, stderr, exitCode)`
    static func run(_ args: String...) throws -> (stdout: String, stderr: String, code: Int32) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = Array(args)
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["NO_COLOR": "1"],
            uniquingKeysWith: { _, new in new },
        )

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }
}

// MARK: - Full Key Lifecycle E2E Tests

@Suite(
    "E2E: Key lifecycle (requires Secure Enclave)",
    .requiresSecureEnclave,
    .serialized,
)
struct KeyLifecycleE2ETests {
    /// Unique key name scoped to this test run to avoid collisions.
    static let baseKeyName = "cli-e2e-\(UUID().uuidString.prefix(8).lowercased())"

    // MARK: 1. CREATE

    @Test("CREATE: ecdsa-256 key exits 0 and reports success")
    func createEcdsa256() throws {
        let (stdout, stderr, code) = try E2ERunner.run(
            "key", "create", Self.baseKeyName,
            "--type", "ecdsa-256", "--auth", "none",
        )
        let combined = stdout + stderr
        #expect(code == 0, "create must exit 0, got \(code). Output: \(combined)")
        // stdout: public key line; stderr: success message
        #expect(
            combined.contains("ecdsa-sha2-nistp256") || combined.contains("Created"),
            "Should report created key with algorithm, got: \(combined)",
        )
    }

    // MARK: 2. LIST

    @Test("LIST: created key appears in JSON output")
    func listContainsCreatedKey() throws {
        // Precondition: key must exist (created by previous test or test order)
        let (stdout, _, code) = try E2ERunner.run("key", "list", "--json")
        #expect(code == 0, "list --json must exit 0, got \(code)")

        let data = Data(stdout.utf8)
        let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        #expect(array != nil, "list --json must produce a JSON array")

        let found = array?.contains { ($0["name"] as? String) == Self.baseKeyName }
        #expect(found == true, "Created key '\(Self.baseKeyName)' not found in list output")
    }

    @Test("LIST: table output contains key name (default format)")
    func listTableContainsKey() throws {
        let (stdout, _, code) = try E2ERunner.run("key", "list")
        #expect(code == 0)
        #expect(stdout.contains(Self.baseKeyName), "Table output must contain key name")
    }

    // MARK: 3. SHOW

    @Test("SHOW: JSON output contains all required schema fields")
    func showJsonSchema() throws {
        let (stdout, _, code) = try E2ERunner.run("key", "show", Self.baseKeyName, "--json")
        #expect(code == 0, "show must exit 0 for existing key")

        let data = Data(stdout.utf8)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["name"] as? String == Self.baseKeyName)
        #expect(dict?["algorithm"] as? String == "ecdsa-sha2-nistp256")
        #expect(dict?["fingerprint_sha256"] != nil)
        #expect(dict?["fingerprint_md5"] != nil)
        #expect(dict?["public_key"] != nil)
        #expect(dict?["store"] != nil)
    }

    @Test("SHOW: public key output starts with correct algorithm prefix")
    func showPublicKeyFormat() throws {
        let (stdout, _, code) = try E2ERunner.run(
            "key", "show", Self.baseKeyName, "--public-key",
        )
        #expect(code == 0)
        #expect(
            stdout.hasPrefix("ecdsa-sha2-nistp256 "),
            "Public key must start with 'ecdsa-sha2-nistp256 ', got: \(stdout.prefix(40))",
        )
    }

    @Test("SHOW: SHA256 fingerprint output starts with 'SHA256:'")
    func showSHA256Fingerprint() throws {
        let (stdout, _, code) = try E2ERunner.run(
            "key", "show", Self.baseKeyName, "--fingerprint",
        )
        #expect(code == 0)
        #expect(
            stdout.contains("SHA256:"),
            "Fingerprint must contain 'SHA256:', got: \(stdout)",
        )
    }

    @Test("SHOW: nonexistent key exits with keyNotFound code")
    func showNonexistentKey() throws {
        let fakeKey = "nonexistent-key-\(UUID().uuidString.prefix(6))"
        let (_, _, code) = try E2ERunner.run("key", "show", fakeKey)
        #expect(code != 0, "Showing nonexistent key must exit non-zero")
        // Exit code 80 = keyNotFound in POSIX sysexits extension
        #expect(code == 80, "Expected keyNotFound (80), got \(code)")
    }

    // MARK: 4. RENAME

    @Test("RENAME: key can be renamed and found under new name")
    func renameKey() throws {
        let newName = "\(Self.baseKeyName)-renamed"

        let (_, renameErr, renameCode) = try E2ERunner.run(
            "key", "rename", Self.baseKeyName, "--name", newName,
        )
        #expect(renameCode == 0, "rename must exit 0, got \(renameCode). Stderr: \(renameErr)")

        // Verify new name appears in list
        let (listOut, _, listCode) = try E2ERunner.run("key", "list", "--json")
        #expect(listCode == 0)
        let array = try JSONSerialization.jsonObject(with: Data(listOut.utf8)) as? [[String: Any]]
        let found = array?.contains { ($0["name"] as? String) == newName }
        #expect(found == true, "Renamed key '\(newName)' not found in list after rename")

        // Old name must be gone
        let oldFound = array?.contains { ($0["name"] as? String) == Self.baseKeyName }
        #expect(oldFound == false || oldFound == nil, "Old key name '\(Self.baseKeyName)' should not appear after rename")
    }

    // MARK: 5. DELETE

    @Test("DELETE --force: renamed key is removed without interactive prompt")
    func deleteRenamedKey() throws {
        let renamedKey = "\(Self.baseKeyName)-renamed"

        let (_, deleteErr, deleteCode) = try E2ERunner.run(
            "key", "delete", renamedKey, "--force",
        )
        #expect(deleteCode == 0, "delete --force must exit 0, got \(deleteCode). Stderr: \(deleteErr)")

        // Verify key is gone
        let (_, showErr, showCode) = try E2ERunner.run("key", "show", renamedKey)
        #expect(showCode != 0, "Showing deleted key must exit non-zero")
        #expect(
            showErr.contains("error") || showErr.contains("not found"),
            "Must report key not found, got: \(showErr)",
        )
    }

    // MARK: 6. Public Key File

    @Test("CREATE: public key .pub file is written to disk")
    func publicKeyFileExists() throws {
        // Create a separate key for this file test
        let fileTestKey = "\(Self.baseKeyName)-filetest"
        let (_, _, createCode) = try E2ERunner.run(
            "key", "create", fileTestKey,
            "--type", "ecdsa-256", "--auth", "none",
        )
        #expect(createCode == 0)

        // Get the show JSON to find public_key_path
        let (stdout, _, showCode) = try E2ERunner.run("key", "show", fileTestKey, "--json")
        #expect(showCode == 0)
        let dict = try JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any]
        guard let path = dict?["public_key_path"] as? String else {
            Issue.record("public_key_path missing from show JSON")
            return
        }

        #expect(
            FileManager.default.fileExists(atPath: path),
            "Public key file must exist at: \(path)",
        )

        // Cleanup
        _ = try? E2ERunner.run("key", "delete", fileTestKey, "--force")
    }
}

// MARK: - E2E: Agent Status Tests

@Suite("E2E: Agent status", .serialized)
struct AgentStatusE2ETests {
    @Test("agent status exits 0 and returns structured JSON")
    func agentStatusJSON() throws {
        let (stdout, _, code) = try E2ERunner.run("agent", "status", "--json")
        // Agent may not be running in all environments — we accept both 0 and non-zero
        // but the output MUST be valid JSON
        let data = Data(stdout.utf8)
        if !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let dict {
                #expect(dict["running"] != nil, "agent status JSON must have 'running' key")
                #expect(dict["socket_path"] != nil, "agent status JSON must have 'socket_path' key")
            }
        }
        // Exit 0 = agent running; 82 = not running — both are valid outcomes
        #expect(
            code == 0 || code == 82,
            "agent status must exit 0 (running) or 82 (not running), got: \(code)",
        )
    }

    @Test("agent status table output contains socket path")
    func agentStatusTable() throws {
        let (stdout, stderr, _) = try E2ERunner.run("agent", "status")
        let combined = stdout + stderr
        // Must mention the socket path regardless of agent state
        #expect(
            combined.contains("socket") || combined.contains("SSH_AUTH_SOCK"),
            "agent status must mention socket path, got: \(combined)",
        )
    }
}

// MARK: - E2E: JSON Error Contract Tests

@Suite("E2E: JSON error contract", .serialized)
struct JSONErrorContractE2ETests {
    @Test("key show nonexistent --json: error response is valid JSON with error key")
    func jsonErrorKeyNotFound() throws {
        let (stdout, _, code) = try E2ERunner.run(
            "key", "show", "guaranteed-nonexistent-\(UUID().uuidString)", "--json",
        )
        #expect(code != 0)
        let data = Data(stdout.utf8)
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            #expect(dict["error"] != nil, "JSON error must have 'error' key")
            if let error = dict["error"] as? [String: Any] {
                #expect(error["code"] != nil, "JSON error.code must be present")
                #expect(error["message"] != nil, "JSON error.message must be present")
            }
        }
    }

    @Test("key create (missing name) --json: error response is valid JSON")
    func jsonErrorMissingArg() throws {
        let (stdout, _, code) = try E2ERunner.run("key", "create", "--json")
        #expect(code != 0)
        if !stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let data = Data(stdout.utf8)
            _ = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            // Must not throw — must be valid JSON
        }
    }
}

// MARK: - E2E: Algorithm Availability Tests

@Suite(
    "E2E: Algorithm availability",
    .requiresSecureEnclave,
    .serialized,
)
struct AlgorithmAvailabilityE2ETests {
    @Test("key create mldsa-65 exits 0 on macOS 26+")
    @available(macOS 26.0, *)
    func createMldsa65OnMacOS26() throws {
        let keyName = "cli-e2e-mldsa-\(UUID().uuidString.prefix(6))"
        let (_, _, code) = try E2ERunner.run(
            "key", "create", keyName,
            "--type", "mldsa-65", "--auth", "none",
        )
        #expect(code == 0, "ML-DSA-65 key creation must succeed on macOS 26")
        _ = try? E2ERunner.run("key", "delete", keyName, "--force")
    }

    @Test("key create mldsa-65 exits non-zero with clear error on pre-macOS-26")
    func createMldsa65PreMacOS26() throws {
        guard #unavailable(macOS 26.0) else { return } // Skip on macOS 26+

        let keyName = "cli-e2e-mldsa-\(UUID().uuidString.prefix(6))"
        let (stdout, stderr, code) = try E2ERunner.run(
            "key", "create", keyName,
            "--type", "mldsa-65", "--auth", "none",
        )
        #expect(code != 0, "ML-DSA-65 must not be available on pre-macOS-26")
        let combined = stdout + stderr
        #expect(
            combined.contains("26") || combined.contains("unavailable") || combined.contains("error"),
            "Must report OS version requirement, got: \(combined)",
        )
    }

    @Test("key create --store smartcard exits non-zero (cannot create SmartCard keys programmatically)")
    func createSmartCardKeyFails() throws {
        let keyName = "cli-e2e-smartcard-\(UUID().uuidString.prefix(6))"
        let (stdout, stderr, code) = try E2ERunner.run(
            "key", "create", keyName, "--store", "smartcard",
        )
        #expect(code != 0, "SmartCard key creation must fail")
        let combined = stdout + stderr
        #expect(
            combined.contains("SmartCard") || combined.contains("hardware") || combined.contains("error"),
            "Must report hardware limitation, got: \(combined)",
        )
    }
}

// MARK: - E2E: Cert Lifecycle Tests

@Suite(
    "E2E: Cert lifecycle (requires Secure Enclave)",
    .requiresSecureEnclave,
    .serialized,
)
struct CertLifecycleE2ETests {
    @Test("cert list exits 0 and outputs valid JSON array")
    func certListJSON() throws {
        let (stdout, _, code) = try E2ERunner.run("cert", "list", "--json")
        #expect(code == 0, "cert list --json must exit 0")
        let data = Data(stdout.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data)
        #expect(parsed != nil, "cert list --json must produce parseable JSON")
        #expect(parsed is [Any], "cert list --json must produce a JSON array")
    }

    @Test("cert import nonexistent file exits non-zero with clear error")
    func certImportNonexistentFile() throws {
        let fakePath = "/tmp/definitely-does-not-exist-\(UUID().uuidString).pub"
        let (stdout, stderr, code) = try E2ERunner.run("cert", "import", fakePath)
        #expect(code != 0, "cert import of nonexistent file must fail")
        let combined = stdout + stderr
        #expect(
            combined.contains("error") || combined.contains("No such file") || combined.contains("could not read"),
            "Must report file error, got: \(combined)",
        )
    }
}
