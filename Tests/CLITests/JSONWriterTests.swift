import Foundation
import Testing
@testable import SecretiveCLI

// MARK: - JSONWriter Tests

@Suite("JSONWriter") @MainActor
struct JSONWriterTests {
    // MARK: - KeyListItem schema

    @Test("KeyListItem encodes all required fields")
    func keyListItemEncoding() throws {
        let item = KeyListItem(
            store: "Secure Enclave",
            name: "github",
            algorithm: "ecdsa-sha2-nistp256",
            authentication: "presenceRequired",
            fingerprint_sha256: "SHA256:abc123",
            fingerprint_md5: "ab:cd:ef",
            public_key: "ecdsa-sha2-nistp256 AAAA...",
            public_key_path: "/tmp/ab.pub",
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["store"] as? String == "Secure Enclave")
        #expect(dict?["name"] as? String == "github")
        #expect(dict?["algorithm"] as? String == "ecdsa-sha2-nistp256")
        #expect(dict?["fingerprint_sha256"] as? String == "SHA256:abc123")
        #expect(dict?["fingerprint_md5"] as? String == "ab:cd:ef")
        #expect(dict?["public_key"] as? String == "ecdsa-sha2-nistp256 AAAA...")
        #expect(dict?["public_key_path"] as? String == "/tmp/ab.pub")
    }

    @Test("KeyListItem has exactly 8 fields in JSON")
    func keyListItemFieldCount() throws {
        let item = KeyListItem(
            store: "SE", name: "k", algorithm: "a",
            authentication: "b", fingerprint_sha256: "c",
            fingerprint_md5: "d", public_key: "e", public_key_path: "f",
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?.count == 8)
    }

    // MARK: - VersionInfo schema

    @Test("VersionInfo encodes all fields")
    func versionInfoEncoding() throws {
        let info = VersionInfo(
            version: "4.0.0",
            build: "42",
            os_version: "macOS 26.0",
            secure_enclave_available: true,
            post_quantum_algorithms: ["mldsa-65", "mldsa-87"],
        )
        let data = try JSONEncoder().encode(info)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["version"] as? String == "4.0.0")
        #expect(dict?["build"] as? String == "42")
        #expect(dict?["os_version"] as? String == "macOS 26.0")
        #expect(dict?["secure_enclave_available"] as? Bool == true)
        let algos = dict?["post_quantum_algorithms"] as? [String]
        #expect(algos == ["mldsa-65", "mldsa-87"])
    }

    @Test("VersionInfo with empty post_quantum_algorithms encodes as empty array")
    func versionInfoEmptyPQAlgos() throws {
        let info = VersionInfo(
            version: "3.0.0", build: "1",
            os_version: "macOS 14.0",
            secure_enclave_available: false,
            post_quantum_algorithms: [],
        )
        let data = try JSONEncoder().encode(info)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let algos = dict?["post_quantum_algorithms"] as? [String]
        #expect(algos?.isEmpty == true)
    }

    // MARK: - AgentStatus schema

    @Test("AgentStatus with nil pid omits pid from JSON")
    func agentStatusNilPid() throws {
        let status = AgentStatus(
            running: false,
            pid: nil,
            socket_path: "/tmp/socket.ssh",
            socket_exists: false,
            keys_loaded: nil,
        )
        let data = try JSONEncoder().encode(status)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["running"] as? Bool == false)
        #expect(dict?["pid"] == nil) // nil optional → absent from JSON
        #expect(dict?["keys_loaded"] == nil)
        #expect(dict?["socket_path"] as? String == "/tmp/socket.ssh")
        #expect(dict?["socket_exists"] as? Bool == false)
    }

    @Test("AgentStatus with pid encodes pid as integer")
    func agentStatusWithPid() throws {
        let status = AgentStatus(
            running: true,
            pid: 1234,
            socket_path: "/tmp/socket.ssh",
            socket_exists: true,
            keys_loaded: 3,
        )
        let data = try JSONEncoder().encode(status)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["running"] as? Bool == true)
        #expect(dict?["pid"] as? Int == 1234)
        #expect(dict?["keys_loaded"] as? Int == 3)
    }

    // MARK: - CertListItem schema

    @Test("CertListItem encodes all required fields")
    func certListItemSchema() throws {
        let item = CertListItem(
            name: "prod-cert",
            key_id: "user@example.com",
            serial: 42,
            principals: ["deploy", "ci"],
            valid_until: "2027-01-15",
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["name"] as? String == "prod-cert")
        #expect(dict?["key_id"] as? String == "user@example.com")
        // serial is UInt64 — JSON may represent as NSNumber
        let serial = dict?["serial"]
        #expect(serial != nil)
        let principals = dict?["principals"] as? [String]
        #expect(principals == ["deploy", "ci"])
        #expect(dict?["valid_until"] as? String == "2027-01-15")
    }

    @Test("CertListItem with nil valid_until encodes as absent key")
    func certListItemNilValidUntil() throws {
        let item = CertListItem(
            name: "forever-cert",
            key_id: "admin",
            serial: 1,
            principals: ["root"],
            valid_until: nil,
        )
        let data = try JSONEncoder().encode(item)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict?["valid_until"] == nil)
    }

    // MARK: - Encoder settings

    @Test("JSONEncoder uses sortedKeys output formatting")
    func sortedKeysEnabled() throws {
        let item = KeyListItem(
            store: "SE", name: "aaa", algorithm: "ecdsa-sha2-nistp256",
            authentication: "presence", fingerprint_sha256: "SHA256:x",
            fingerprint_md5: "MD5:x", public_key: "pub", public_key_path: "/p",
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(item)
        let str = try #require(String(data: data, encoding: .utf8))
        // Extract keys in order of appearance
        var keys: [String] = []
        for line in str.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let range = trimmed.range(of: "\"([a-z_]+)\" :", options: .regularExpression) {
                let key = String(trimmed[range])
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: " :", with: "")
                keys.append(key)
            }
        }
        #expect(keys == keys.sorted(), "Keys should appear in sorted order")
    }

    @Test("JSON output does not escape forward slashes")
    func withoutEscapingSlashes() throws {
        let item = KeyListItem(
            store: "SE", name: "k", algorithm: "a",
            authentication: "b", fingerprint_sha256: "c",
            fingerprint_md5: "d", public_key: "e",
            public_key_path: "/Users/x/Library/Containers/xyz/PublicKeys/abc.pub",
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(item)
        let str = try #require(String(data: data, encoding: .utf8))
        #expect(str.contains("/Users/x/Library"), "Slashes must not be escaped")
        #expect(!str.contains("\\/"), "Escaped slashes must not be present")
    }

    // MARK: - Encodable smoke test

    @Test("Encodes generic Encodable struct without crashing")
    func encodesSimpleStruct() throws {
        struct Payload: Encodable { let name: String
            let count: Int
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Payload(name: "test", count: 42))
        let str = String(data: data, encoding: .utf8)
        #expect(str?.contains("\"count\" : 42") == true)
        #expect(str?.contains("\"name\" : \"test\"") == true)
    }
}
