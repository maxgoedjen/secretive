import Foundation
import SecretKit
import Testing
@testable import SecretiveCLI

// MARK: - Key Lookup Tests

/// MockSecret for unit tests — no Keychain access required.
struct MockSecret: SecretKit.Secret {
    var id: String
    var name: String
    var publicKey: Data
    var attributes: Attributes
}

extension MockSecret {
    static func make(
        id: String = UUID().uuidString,
        name: String,
        auth: AuthenticationRequirement = .presenceRequired,
    ) -> MockSecret {
        MockSecret(
            id: id,
            name: name,
            publicKey: Data(name.utf8),
            attributes: Attributes(keyType: .ecdsa256, authentication: auth),
        )
    }
}

// MARK: - KeyCommands.formatAlgorithm

@Suite("KeyCommands.formatAlgorithm") @MainActor
struct FormatAlgorithmTests {
    @Test("ecdsa256 → ecdsa-sha2-nistp256")
    func formatEcdsa256() {
        #expect(KeyCommands.formatAlgorithm(.ecdsa256) == "ecdsa-sha2-nistp256")
    }

    @Test("ecdsa384 → ecdsa-sha2-nistp384")
    func formatEcdsa384() {
        #expect(KeyCommands.formatAlgorithm(.ecdsa384) == "ecdsa-sha2-nistp384")
    }

    @Test("mldsa65 → mldsa-65")
    func formatMldsa65() {
        #expect(KeyCommands.formatAlgorithm(.mldsa65) == "mldsa-65")
    }

    @Test("mldsa87 → mldsa-87")
    func formatMldsa87() {
        #expect(KeyCommands.formatAlgorithm(.mldsa87) == "mldsa-87")
    }

    @Test("rsa2048 → rsa-2048")
    func formatRsa2048() {
        #expect(KeyCommands.formatAlgorithm(.rsa2048) == "rsa-2048")
    }

    @Test("Unknown KeyType falls through to description")
    func formatUnknownFallthrough() {
        // A KeyType with no explicit case falls through to keyType.description
        let custom = KeyType(algorithm: .ecdsa, size: 521)
        let result = KeyCommands.formatAlgorithm(custom)
        // Must be non-empty string — exact value comes from description
        #expect(!result.isEmpty)
    }
}

// MARK: - KeyCommands.formatAuth

@Suite("KeyCommands.formatAuth") @MainActor
struct FormatAuthTests {
    @Test("Maps all AuthenticationRequirement cases")
    func formatAllAuthCases() {
        #expect(KeyCommands.formatAuth(.notRequired) == "none")
        #expect(KeyCommands.formatAuth(.presenceRequired) == "presence")
        #expect(KeyCommands.formatAuth(.biometryCurrent) == "biometry-current")
        #expect(KeyCommands.formatAuth(.unknown) == "unknown")
    }
}

// MARK: - CLIError

@Suite("CLIError") @MainActor
struct CLIErrorTests {
    @Test("keyNotFound description contains the identifier")
    func keyNotFoundDescription() {
        let error = CLIError.keyNotFound("github")
        #expect(error.description.contains("github"))
        #expect(error.exitCode == .keyNotFound)
    }

    @Test("ambiguousKey description lists all candidates")
    func ambiguousKeyDescription() {
        let error = CLIError.ambiguousKey("dep", candidates: ["deploy", "deploy-old"])
        #expect(error.description.contains("deploy"))
        #expect(error.description.contains("deploy-old"))
        #expect(error.exitCode == .ambiguous)
    }

    @Test("usageError has .usage exit code (EX_USAGE = 64)")
    func usageErrorCode() {
        let error = CLIError.usageError("missing argument")
        #expect(error.exitCode == .usage)
        #expect(error.exitCode.rawValue == 64)
    }

    @Test("agentNotRunning has correct custom exit code (82)")
    func agentNotRunningCode() {
        let error = CLIError.agentNotRunning
        #expect(error.exitCode == .agentNotRunning)
        #expect(error.exitCode.rawValue == 82)
    }

    @Test("keychainError has .noPerm exit code and contains OSStatus")
    func keychainErrorCode() {
        let error = CLIError.keychainError(-34018)
        #expect(error.exitCode == .noPerm)
        #expect(error.description.contains("-34018"))
    }

    @Test("ioError description contains the message")
    func ioErrorContainsMessage() {
        let error = CLIError.ioError("disk full")
        #expect(error.description.contains("disk full"))
        #expect(error.exitCode == .cantCreate)
    }

    @Test("algorithmUnavailable description contains algo name and macOS 26")
    func algorithmUnavailableMessage() {
        let error = CLIError.algorithmUnavailable("mldsa-65")
        #expect(error.description.contains("mldsa-65"))
        #expect(error.description.contains("26"))
        #expect(error.exitCode == .unavailable)
    }

    @Test("storeUnavailable description contains store name")
    func storeUnavailableMessage() {
        let error = CLIError.storeUnavailable("YubiKey 5")
        #expect(error.description.contains("YubiKey 5"))
        #expect(error.exitCode == .unavailable)
    }

    @Test("secureEnclaveUnavailable description mentions Secure Enclave")
    func secureEnclaveUnavailableMessage() {
        let error = CLIError.secureEnclaveUnavailable
        #expect(error.description.contains("Secure Enclave"))
        #expect(error.exitCode == .unavailable)
    }

    @Test("operationUnsupported description passes through message")
    func operationUnsupportedMessage() {
        let error = CLIError.operationUnsupported("SmartCard keys cannot be created programmatically")
        #expect(error.description.contains("SmartCard keys cannot be created"))
        #expect(error.exitCode == .unsupported)
    }

    @Test("All ExitCode raw values are unique (no collisions)")
    func allExitCodesUnique() {
        let codes: [ExitCode] = [
            .ok, .usage, .dataError, .unavailable, .software,
            .cantCreate, .noPerm, .config, .keyNotFound,
            .ambiguous, .agentNotRunning, .unsupported,
        ]
        let rawValues = codes.map(\.rawValue)
        #expect(
            Set(rawValues).count == rawValues.count,
            "Duplicate exit code detected — all raw values must be unique",
        )
    }

    @Test("ExitCode.usage matches POSIX EX_USAGE = 64")
    func usageCodeMatchesPOSIX() {
        #expect(ExitCode.usage.rawValue == 64)
    }

    @Test("ExitCode.dataError matches POSIX EX_DATAERR = 65")
    func dataErrorCodeMatchesPOSIX() {
        #expect(ExitCode.dataError.rawValue == 65)
    }

    @Test("ExitCode.unavailable matches POSIX EX_UNAVAILABLE = 69")
    func unavailableCodeMatchesPOSIX() {
        #expect(ExitCode.unavailable.rawValue == 69)
    }

    @Test("ExitCode.ok is 0")
    func okCodeIsZero() {
        #expect(ExitCode.ok.rawValue == 0)
    }
}

// MARK: - StoreProvider path tests

@Suite("StoreProvider") @MainActor
struct StoreProviderTests {
    @Test("socketPath is an absolute path")
    func socketPathIsAbsolute() {
        #expect(StoreProvider.socketPath.hasPrefix("/"))
    }

    @Test("socketPath ends with socket.ssh")
    func socketPathEndsWithSocket() {
        let path = StoreProvider.socketPath
        #expect(
            path.hasSuffix("socket.ssh") || path.hasSuffix("socket-debug.ssh"),
            "Socket path must end with socket.ssh or socket-debug.ssh, got: \(path)",
        )
    }

    @Test("socketPath contains SecretAgent bundle ID segment")
    func socketPathContainsBundleID() {
        let path = StoreProvider.socketPath
        // The path goes through the SecretAgent container
        #expect(
            path.contains("SecretAgent") || path.contains("Secretive"),
            "Socket path should reference the SecretAgent container, got: \(path)",
        )
    }

    @Test("publicKeyDirectory is an absolute URL")
    func publicKeyDirectoryIsAbsolute() {
        let dir = StoreProvider.publicKeyDirectory
        #expect(dir.path.hasPrefix("/"))
    }

    @Test("publicKeyDirectory ends with PublicKeys")
    func publicKeyDirectoryEndsWithPublicKeys() {
        let dir = StoreProvider.publicKeyDirectory
        #expect(dir.lastPathComponent == "PublicKeys")
    }
}

// MARK: - Notifications name tests

@Suite("Notifications") @MainActor
struct NotificationsTests {
    @Test("secretStoreUpdated notification name matches Secretive protocol")
    func secretStoreUpdatedName() {
        let name = NSNotification.Name.secretStoreUpdated
        #expect(name.rawValue == "com.maxgoedjen.Secretive.secretStore.updated")
    }

    @Test("certificateStoreUpdated notification name matches Secretive protocol")
    func certificateStoreUpdatedName() {
        let name = NSNotification.Name.certificateStoreUpdated
        #expect(name.rawValue == "com.maxgoedjen.Secretive.certificateStore.updated")
    }
}
