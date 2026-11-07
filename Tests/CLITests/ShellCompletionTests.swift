import Foundation
import Testing

// MARK: - Shell Completion Tests

@Suite("ShellCompletions")
struct ShellCompletionTests {
    /// Resolves the Resources/completions directory relative to the package root.
    static var completionsDirectory: URL {
        // Walk up from this source file: Tests/CLITests/ → Tests/ → (root)
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CLITests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("Resources/completions")
    }

    // MARK: - File existence

    @Test("zsh completion file exists")
    func zshFileExists() {
        let url = Self.completionsDirectory.appendingPathComponent("_secretive")
        #expect(
            FileManager.default.fileExists(atPath: url.path),
            "Missing: \(url.path)",
        )
    }

    @Test("bash completion file exists")
    func bashFileExists() {
        let url = Self.completionsDirectory.appendingPathComponent("secretive.bash")
        #expect(
            FileManager.default.fileExists(atPath: url.path),
            "Missing: \(url.path)",
        )
    }

    @Test("fish completion file exists")
    func fishFileExists() {
        let url = Self.completionsDirectory.appendingPathComponent("secretive.fish")
        #expect(
            FileManager.default.fileExists(atPath: url.path),
            "Missing: \(url.path)",
        )
    }

    // MARK: - Content non-empty

    @Test(arguments: ["_secretive", "secretive.bash", "secretive.fish"])
    func completionFileIsNonEmpty(filename: String) throws {
        let url = Self.completionsDirectory.appendingPathComponent(filename)
        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.isEmpty, "\(filename) must not be empty")
    }

    // MARK: - Command coverage

    @Test("zsh completion covers all top-level commands")
    func zshCoversAllCommands() throws {
        let url = Self.completionsDirectory.appendingPathComponent("_secretive")
        let content = try String(contentsOf: url, encoding: .utf8)
        for cmd in ["key", "cert", "agent", "env", "version"] {
            #expect(content.contains(cmd), "zsh completion missing command: \(cmd)")
        }
    }

    @Test("bash completion covers all top-level commands")
    func bashCoversAllCommands() throws {
        let url = Self.completionsDirectory.appendingPathComponent("secretive.bash")
        let content = try String(contentsOf: url, encoding: .utf8)
        for cmd in ["key", "cert", "agent", "env", "version"] {
            #expect(content.contains(cmd), "bash completion missing command: \(cmd)")
        }
    }

    @Test("fish completion covers all top-level commands")
    func fishCoversAllCommands() throws {
        let url = Self.completionsDirectory.appendingPathComponent("secretive.fish")
        let content = try String(contentsOf: url, encoding: .utf8)
        for cmd in ["key", "cert", "agent", "env", "version"] {
            #expect(content.contains(cmd), "fish completion missing command: \(cmd)")
        }
    }

    @Test("zsh completion covers key subcommands")
    func zshCoversKeySubcommands() throws {
        let url = Self.completionsDirectory.appendingPathComponent("_secretive")
        let content = try String(contentsOf: url, encoding: .utf8)
        for sub in ["list", "show", "create", "delete", "rename"] {
            #expect(content.contains(sub), "zsh completion missing key subcommand: \(sub)")
        }
    }
}
