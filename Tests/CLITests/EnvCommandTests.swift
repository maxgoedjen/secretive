import Foundation
import Testing
@testable import SecretiveCLI

// MARK: - EnvCommand Tests

@Suite("EnvCommand") @MainActor
struct EnvCommandTests {
    // MARK: - Shell enum

    @Test("Shell enum parses 'zsh' correctly")
    func shellZsh() {
        #expect(EnvCommand.Shell(rawValue: "zsh") == .zsh)
    }

    @Test("Shell enum parses 'bash' correctly")
    func shellBash() {
        #expect(EnvCommand.Shell(rawValue: "bash") == .bash)
    }

    @Test("Shell enum parses 'fish' correctly")
    func shellFish() {
        #expect(EnvCommand.Shell(rawValue: "fish") == .fish)
    }

    @Test("Shell enum returns nil for unsupported shell name")
    func shellUnsupported() {
        #expect(EnvCommand.Shell(rawValue: "powershell") == nil)
        #expect(EnvCommand.Shell(rawValue: "nushell") == nil)
        #expect(EnvCommand.Shell(rawValue: "") == nil)
    }

    @Test("Shell enum is case-sensitive (uppercase is rejected)")
    func shellCaseSensitive() {
        #expect(EnvCommand.Shell(rawValue: "ZSH") == nil)
        #expect(EnvCommand.Shell(rawValue: "Bash") == nil)
    }

    // MARK: - socketPath format

    @Test("socketPath is an absolute path")
    func socketPathAbsolute() {
        let path = StoreProvider.socketPath
        #expect(path.hasPrefix("/"), "socketPath must be absolute, got: \(path)")
    }

    @Test("socketPath references SecretAgent container")
    func socketPathReferencesAgent() {
        let path = StoreProvider.socketPath
        #expect(
            path.contains("SecretAgent") || path.contains("Secretive"),
            "socketPath must reference the agent container, got: \(path)",
        )
    }

    @Test("socketPath ends with .ssh extension")
    func socketPathExtension() {
        let path = StoreProvider.socketPath
        #expect(path.hasSuffix(".ssh"), "socketPath must end with .ssh, got: \(path)")
    }
}
