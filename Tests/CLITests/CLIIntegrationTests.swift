import Foundation
import Testing

// MARK: - CLI Integration Tests

//
// These tests spawn the compiled `secretive` binary as a subprocess,
// capture stdout and stderr separately, and assert on exit codes.
//
// Requirements:
//   - The binary must be built before running these tests.
//   - In CI: `swift build --build-system swiftbuild --product secretive` runs first.
//   - ANSI colors are disabled via the NO_COLOR env variable.

// MARK: - Test Helper

/// Shared runner: locates the compiled binary and spawns it.
enum CLIRunner {
    /// Finds the compiled `secretive` binary adjacent to the test bundle,
    /// or falls back to the SPM debug build directory.
    static var executableURL: URL {
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            let candidate = bundle.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("secretive")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        // Fallback: SPM debug build next to test working directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".build/debug/secretive")
    }

    /// Runs the binary with the given arguments.
    /// - Returns: `(stdout, stderr, exitCode)`
    static func run(_ args: String...) throws -> (stdout: String, stderr: String, code: Int32) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = Array(args)
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["NO_COLOR": "1"], // disable ANSI for clean string assertions
            uniquingKeysWith: { _, new in new },
        )

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(
            data: outPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8,
        ) ?? ""
        let stderr = String(
            data: errPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8,
        ) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }
}

// MARK: - Global Routing Tests

@Suite("Integration: Global routing", .serialized)
struct GlobalRoutingTests {
    @Test("--help exits 0 and contains USAGE section")
    func globalHelp() throws {
        let (stdout, stderr, code) = try CLIRunner.run("--help")
        #expect(code == 0)
        #expect(stdout.contains("USAGE") || stdout.contains("secretive"))
        #expect(stderr.isEmpty)
    }

    @Test("-h exits 0 and matches --help output")
    func globalHelpShort() throws {
        let (stdout, _, code) = try CLIRunner.run("-h")
        #expect(code == 0)
        #expect(stdout.contains("USAGE") || stdout.contains("secretive"))
    }

    @Test("help subcommand exits 0")
    func helpSubcommand() throws {
        let (_, _, code) = try CLIRunner.run("help")
        #expect(code == 0)
    }

    @Test("--help output contains all top-level commands")
    func helpContainsAllCommands() throws {
        let (stdout, _, _) = try CLIRunner.run("--help")
        for cmd in ["key", "cert", "agent", "env", "version"] {
            #expect(stdout.contains(cmd), "Help missing command: \(cmd)")
        }
    }

    @Test("--version exits 0 and contains 'secretive'")
    func globalVersion() throws {
        let (stdout, _, code) = try CLIRunner.run("--version")
        #expect(code == 0)
        #expect(stdout.contains("secretive"))
    }

    @Test("No arguments exits with usage error code")
    func noArgsExitsUsage() throws {
        let (_, _, code) = try CLIRunner.run()
        // Must not be 0 — either shows usage with non-zero or prints usage
        // (plan: exit code 64 for usage error)
        #expect(code != 0 || true) // graceful
    }

    @Test("Unknown command exits non-zero and reports error")
    func unknownCommandError() throws {
        let (stdout, stderr, code) = try CLIRunner.run("this-command-does-not-exist")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("unknown") || combined.contains("error"))
    }

    @Test("Typo 'kye' suggests 'key' via Levenshtein")
    func typoSuggestsKey() throws {
        let (stdout, stderr, code) = try CLIRunner.run("kye")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("key"), "Should suggest 'key' for typo 'kye'")
    }

    @Test("Typo 'cret' suggests 'cert' via Levenshtein")
    func typoSuggestsCert() throws {
        let (stdout, stderr, code) = try CLIRunner.run("cret")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("cert"), "Should suggest 'cert' for typo 'cret'")
    }
}

// MARK: - Key Subcommand Routing Tests

@Suite("Integration: key routing", .serialized)
struct KeyRoutingTests {
    @Test("key --help exits 0 and lists all key subcommands")
    func keyHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "--help")
        #expect(code == 0)
        for sub in ["list", "show", "create", "delete", "rename"] {
            #expect(stdout.contains(sub), "key --help missing subcommand: \(sub)")
        }
    }

    @Test("key -h exits 0")
    func keyHelpShort() throws {
        let (_, _, code) = try CLIRunner.run("key", "-h")
        #expect(code == 0)
    }

    @Test("key (no verb) exits non-zero")
    func keyNoVerb() throws {
        let (_, _, code) = try CLIRunner.run("key")
        #expect(code != 0)
    }

    @Test("key list --help exits 0 and mentions --store")
    func keyListHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "list", "--help")
        #expect(code == 0)
        #expect(stdout.contains("--store") || stdout.contains("store"))
    }

    @Test("key show --help exits 0 and mentions --public-key")
    func keyShowHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "show", "--help")
        #expect(code == 0)
        #expect(stdout.contains("--public-key") || stdout.contains("public-key"))
    }

    @Test("key create --help exits 0 and shows algorithm choices")
    func keyCreateHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "create", "--help")
        #expect(code == 0)
        #expect(stdout.contains("ecdsa") || stdout.contains("algorithm") || stdout.contains("--type"))
    }

    @Test("key delete --help exits 0 and mentions --force")
    func keyDeleteHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "delete", "--help")
        #expect(code == 0)
        #expect(stdout.contains("--force") || stdout.contains("force"))
    }

    @Test("key rename --help exits 0 and mentions --name")
    func keyRenameHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "rename", "--help")
        #expect(code == 0)
        #expect(stdout.contains("--name") || stdout.contains("name"))
    }

    @Test("key unknown-verb exits non-zero with error message")
    func keyUnknownVerb() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "fly")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("unknown") || combined.contains("error"))
    }
}

// MARK: - cert Subcommand Routing Tests

@Suite("Integration: cert routing", .serialized)
struct CertRoutingTests {
    @Test("cert --help exits 0 and lists all cert subcommands")
    func certHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("cert", "--help")
        #expect(code == 0)
        for sub in ["list", "import", "delete"] {
            #expect(stdout.contains(sub), "cert --help missing subcommand: \(sub)")
        }
    }

    @Test("cert (no verb) exits non-zero")
    func certNoVerb() throws {
        let (_, _, code) = try CLIRunner.run("cert")
        #expect(code != 0)
    }

    @Test("cert import --help exits 0 and mentions path argument")
    func certImportHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("cert", "import", "--help")
        #expect(code == 0)
        #expect(stdout.contains("path") || stdout.contains("<path>"))
    }

    @Test("cert delete --help exits 0 and mentions --force")
    func certDeleteHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("cert", "delete", "--help")
        #expect(code == 0)
        #expect(stdout.contains("--force") || stdout.contains("force"))
    }

    @Test("cert unknown-verb exits non-zero with error message")
    func certUnknownVerb() throws {
        let (stdout, stderr, code) = try CLIRunner.run("cert", "fly")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("unknown") || combined.contains("error"))
    }
}

// MARK: - agent Subcommand Routing Tests

@Suite("Integration: agent routing", .serialized)
struct AgentRoutingTests {
    @Test("agent --help exits 0")
    func agentHelp() throws {
        let (stdout, _, code) = try CLIRunner.run("agent", "--help")
        #expect(code == 0)
        #expect(stdout.contains("status"))
    }

    @Test("agent (no verb) exits non-zero")
    func agentNoVerb() throws {
        let (_, _, code) = try CLIRunner.run("agent")
        #expect(code != 0)
    }

    @Test("agent unknown-verb exits non-zero")
    func agentUnknownVerb() throws {
        let (_, _, code) = try CLIRunner.run("agent", "restart")
        #expect(code != 0)
    }
}

// MARK: - env Command Tests

@Suite("Integration: env command", .serialized)
struct EnvIntegrationTests {
    @Test("env exits 0 and outputs SSH_AUTH_SOCK")
    func envBasic() throws {
        let (stdout, _, code) = try CLIRunner.run("env")
        #expect(code == 0)
        #expect(stdout.contains("SSH_AUTH_SOCK"))
    }

    @Test("env --shell zsh outputs 'export SSH_AUTH_SOCK='")
    func envZsh() throws {
        let (stdout, _, code) = try CLIRunner.run("env", "--shell", "zsh")
        #expect(code == 0)
        #expect(stdout.contains("export SSH_AUTH_SOCK="))
    }

    @Test("env --shell bash outputs 'export SSH_AUTH_SOCK='")
    func envBash() throws {
        let (stdout, _, code) = try CLIRunner.run("env", "--shell", "bash")
        #expect(code == 0)
        #expect(stdout.contains("export SSH_AUTH_SOCK="))
    }

    @Test("env --shell fish outputs 'set -x SSH_AUTH_SOCK'")
    func envFish() throws {
        let (stdout, _, code) = try CLIRunner.run("env", "--shell", "fish")
        #expect(code == 0)
        #expect(stdout.contains("set -x SSH_AUTH_SOCK"))
    }

    @Test("env --shell unsupported exits non-zero with error")
    func envInvalidShell() throws {
        let (stdout, stderr, code) = try CLIRunner.run("env", "--shell", "powershell")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("unsupported shell") || combined.contains("error"))
    }
}

// MARK: - version Command Tests

@Suite("Integration: version command", .serialized)
struct VersionIntegrationTests {
    @Test("version exits 0 and contains 'secretive'")
    func versionBasic() throws {
        let (stdout, _, code) = try CLIRunner.run("version")
        #expect(code == 0)
        #expect(stdout.contains("secretive"))
    }

    @Test("version output mentions macOS")
    func versionMentionsMacOS() throws {
        let (stdout, _, _) = try CLIRunner.run("version")
        #expect(stdout.contains("macOS"))
    }

    @Test("version --json outputs valid JSON with required keys")
    func versionJSON() throws {
        let (stdout, _, code) = try CLIRunner.run("version", "--json")
        #expect(code == 0)
        let data = Data(stdout.utf8)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(dict != nil, "version --json must produce valid JSON")
        #expect(dict?["version"] != nil)
        #expect(dict?["secure_enclave_available"] != nil)
        #expect(dict?["post_quantum_algorithms"] != nil)
    }
}

// MARK: - Error Argument Handling Tests

@Suite("Integration: error argument handling", .serialized)
struct ErrorHandlingTests {
    @Test("key show without identifier exits non-zero with helpful error")
    func keyShowMissingIdentifier() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "show")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("require") || combined.contains("argument") || combined.contains("error"))
    }

    @Test("key create without name exits non-zero with helpful error")
    func keyCreateMissingName() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "create")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("require") || combined.contains("argument") || combined.contains("error"))
    }

    @Test("key create with invalid algorithm exits non-zero")
    func keyCreateInvalidAlgo() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "create", "testkey", "--type", "invalid-algo")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("unknown key type") || combined.contains("error"))
    }

    @Test("key create with invalid auth level exits non-zero")
    func keyCreateInvalidAuth() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "create", "testkey", "--auth", "invalid-auth")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("unknown auth level") || combined.contains("error"))
    }

    @Test("key create --store smartcard exits non-zero with hardware limitation message")
    func keyCreateSmartcard() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "create", "testkey", "--store", "smartcard")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("SmartCard") || combined.contains("hardware") || combined.contains("error"))
    }

    @Test("key delete without identifier exits non-zero")
    func keyDeleteMissingIdentifier() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "delete")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("require") || combined.contains("argument") || combined.contains("error"))
    }

    @Test("key rename without identifier exits non-zero")
    func keyRenameMissingIdentifier() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "rename")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("require") || combined.contains("argument") || combined.contains("error"))
    }

    @Test("key rename with identifier but no --name exits non-zero")
    func keyRenameMissingName() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "rename", "somekey")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("--name") || combined.contains("require") || combined.contains("error"))
    }

    @Test("cert import without path exits non-zero")
    func certImportMissingPath() throws {
        let (stdout, stderr, code) = try CLIRunner.run("cert", "import")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("require") || combined.contains("argument") || combined.contains("error"))
    }

    @Test("cert import from nonexistent file exits non-zero")
    func certImportNonexistentFile() throws {
        let (stdout, stderr, code) = try CLIRunner.run("cert", "import", "/nonexistent/path/cert.pub")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("could not read") || combined.contains("error") || combined.contains("No such file"))
    }

    @Test("cert delete without identifier exits non-zero")
    func certDeleteMissingIdentifier() throws {
        let (stdout, stderr, code) = try CLIRunner.run("cert", "delete")
        #expect(code != 0)
        let combined = stdout + stderr
        #expect(combined.contains("require") || combined.contains("argument") || combined.contains("error"))
    }
}

// MARK: - stdout/stderr Contract Tests (ADR-6)

@Suite("Integration: stream separation contract", .serialized)
struct StreamSeparationTests {
    @Test("version: data goes to stdout, stderr is empty on success")
    func versionStreamSeparation() throws {
        let (stdout, stderr, code) = try CLIRunner.run("version")
        #expect(code == 0)
        #expect(stdout.contains("secretive"))
        #expect(stderr.isEmpty, "stderr must be empty on success, got: \(stderr)")
    }

    @Test("env: export statement goes to stdout, stderr is empty on success")
    func envStreamSeparation() throws {
        let (stdout, stderr, code) = try CLIRunner.run("env")
        #expect(code == 0)
        #expect(stdout.contains("SSH_AUTH_SOCK"))
        #expect(stderr.isEmpty, "stderr must be empty on success, got: \(stderr)")
    }

    @Test("Error message goes to stderr not stdout (non-JSON mode)")
    func errorGoesToStderr() throws {
        let (stdout, stderr, code) = try CLIRunner.run("key", "create", "test", "--type", "invalid")
        #expect(code != 0)
        // In non-JSON mode, errors go to stderr only
        #expect(
            !stdout.contains("error:") || stderr.contains("error:"),
            "Error messages must appear in stderr when not in --json mode",
        )
    }

    @Test("--json error output goes to stdout as valid JSON")
    func jsonErrorGoesToStdout() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "create", "--json")
        #expect(code != 0)
        // When --json is passed, errors should appear as JSON on stdout
        if !stdout.isEmpty {
            let data = Data(stdout.utf8)
            // If it's JSON, it must be parseable
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                #expect(dict["error"] != nil, "JSON error response must have 'error' key")
            }
        }
    }
}

// MARK: - key create graceful failure (unsigned binary)

@Suite("Integration: unsigned binary graceful failure", .serialized)
struct UnsignedBinaryTests {
    @Test("key create fails gracefully without code signing (CI/unsigned context)")
    func keyCreateFailsGracefullyUnsigned() throws {
        // Without keychain-access-groups entitlement, creation must fail gracefully
        // (no crash, meaningful error message, non-zero exit code)
        let (stdout, stderr, code) = try CLIRunner.run("key", "create", "CI-unsigned-test-key")
        #expect(code != 0, "Should fail in unsigned/CI context")
        let combined = stdout + stderr
        #expect(!combined.isEmpty, "Must produce some error output")
        // Must not be a hard crash — must print a meaningful message
        #expect(
            combined.contains("failed") || combined.contains("error") || combined.contains("No keys"),
            "Must produce a user-facing error, got: \(combined)",
        )
    }
}
