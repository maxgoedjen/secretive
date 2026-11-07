import Foundation
import Testing

// MARK: - CLI Output Snapshot Tests

//
// Golden-file snapshot tests: verify that the CLI's human-readable
// output format doesn't change unexpectedly between releases.
//
// How it works:
//   1. Run the CLI and capture stdout.
//   2. Compare against the golden file in Tests/CLITests/Snapshots/.
//   3. On first run (no golden file yet): write the golden file and PASS.
//   4. On subsequent runs: diff against the golden file and FAIL if changed.
//
// To intentionally update a snapshot after a design change:
//   rm Tests/CLITests/Snapshots/<name>.txt && swift test --filter SnapshotTests
//
// Note: Snapshot content is normalised (trailing whitespace stripped,
// version numbers masked) so that they survive version bumps.

// MARK: - Snapshot Helper

enum Snapshot {
    static var snapshotsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CLITests/
            .appendingPathComponent("Snapshots")
    }

    /// Normalises CLI output for stable snapshot comparison.
    /// - Strips ANSI codes (guaranteed off via NO_COLOR=1)
    /// - Masks version strings (1.2.3 → <VERSION>)
    /// - Masks macOS version strings (macOS 26.0.1 (26A…) → macOS <VERSION>)
    /// - Strips trailing whitespace on each line
    static func normalize(_ raw: String) -> String {
        var result = raw

        // Helper: apply NSRegularExpression substitution safely
        func replace(_ pattern: String, with template: String, in s: String) -> String {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return s }
            let range = NSRange(s.startIndex..., in: s)
            return re.stringByReplacingMatches(in: s, range: range, withTemplate: template)
        }

        // Mask semantic and OS version numbers (e.g. 1.2.3, 27.2, 15.0.1)
        result = replace(#"\b\d+\.\d+(\.\d+)*\b"#, with: "<VERSION>", in: result)
        // Mask macOS parenthetical build tags (e.g. (Build 26B5091g) or (26A1234))
        result = replace(#"\((Build\s+)?[0-9A-Za-z]+\)"#, with: "(<BUILD>)", in: result)

        // Strip trailing whitespace per line
        result = result
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression) }
            .joined(separator: "\n")
        return result
    }

    /// Loads or creates a golden snapshot file.
    /// - Returns: existing snapshot content, or nil if it should be (re)created.
    static func load(named name: String) -> String? {
        let url = snapshotsDirectory.appendingPathComponent("\(name).txt")
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Writes a new golden snapshot.
    static func write(_ content: String, named name: String) throws {
        try FileManager.default.createDirectory(
            at: snapshotsDirectory,
            withIntermediateDirectories: true,
        )
        let url = snapshotsDirectory.appendingPathComponent("\(name).txt")
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Asserts that `actual` matches the stored snapshot for `name`.
    /// Creates the snapshot if it doesn't exist yet.
    static func assert(
        actual: String,
        named name: String,
        sourceLocation: Testing.SourceLocation = #_sourceLocation,
    ) throws {
        let normalised = normalize(actual)

        if let stored = load(named: name) {
            #expect(
                normalised == stored,
                "Snapshot '\(name)' changed.\nRun: rm Tests/CLITests/Snapshots/\(name).txt to update.\n\nExpected:\n\(stored)\n\nActual:\n\(normalised)",
                sourceLocation: sourceLocation,
            )
        } else {
            // First run — write the golden file and pass
            try write(normalised, named: name)
        }
    }
}

// MARK: - Snapshot Test Suite

@Suite("CLI output snapshots", .serialized)
struct SnapshotTests {
    @Test("global --help output matches snapshot")
    func globalHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "global-help")
    }

    @Test("key --help output matches snapshot")
    func keyHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "key-help")
    }

    @Test("key list --help output matches snapshot")
    func keyListHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "list", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "key-list-help")
    }

    @Test("key create --help output matches snapshot")
    func keyCreateHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("key", "create", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "key-create-help")
    }

    @Test("cert --help output matches snapshot")
    func certHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("cert", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "cert-help")
    }

    @Test("agent --help output matches snapshot")
    func agentHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("agent", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "agent-help")
    }

    @Test("env --help output matches snapshot")
    func envHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("env", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "env-help")
    }

    @Test("version --help output matches snapshot")
    func versionHelpSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("version", "--help")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "version-help")
    }

    @Test("env --shell zsh output matches snapshot")
    func envZshSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("env", "--shell", "zsh")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "env-zsh")
    }

    @Test("version output (table) matches snapshot structure")
    func versionTableSnapshot() throws {
        let (stdout, _, code) = try CLIRunner.run("version")
        #expect(code == 0)
        try Snapshot.assert(actual: stdout, named: "version-table")
    }
}
