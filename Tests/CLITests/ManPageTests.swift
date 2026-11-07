import Foundation
import Testing

// MARK: - Man Page Tests

@Suite("ManPage")
struct ManPageTests {
    static var manPageURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CLITests/
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // project root
            .appendingPathComponent("Resources/man/secretive.1")
    }

    @Test("Man page file exists at Resources/man/secretive.1")
    func manPageExists() {
        #expect(
            FileManager.default.fileExists(atPath: Self.manPageURL.path),
            "Missing man page: \(Self.manPageURL.path)",
        )
    }

    @Test("Man page starts with .TH (troff title heading)")
    func manPageStartsWithTH() throws {
        let content = try String(contentsOf: Self.manPageURL, encoding: .utf8)
        #expect(
            content.hasPrefix(".TH") || content.contains(".TH"),
            "Man page must contain a .TH title heading directive",
        )
    }

    @Test("Man page references 'secretive' command name")
    func manPageContainsCommandName() throws {
        let content = try String(contentsOf: Self.manPageURL, encoding: .utf8)
        let lower = content.lowercased()
        #expect(lower.contains("secretive"), "Man page must mention 'secretive'")
    }

    @Test("Man page is non-empty")
    func manPageNonEmpty() throws {
        let content = try String(contentsOf: Self.manPageURL, encoding: .utf8)
        #expect(content.count > 100, "Man page seems too short (\(content.count) bytes)")
    }
}
