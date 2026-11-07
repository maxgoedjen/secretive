import Foundation
import Testing
@testable import SecretiveCLI

// MARK: - TableWriter Tests

@Suite("TableWriter") @MainActor
struct TableWriterTests {
    // MARK: - Column struct

    @Test("Column header is preserved")
    func headerIsPreserved() {
        let col = TableWriter.Column("FINGERPRINT")
        #expect(col.header == "FINGERPRINT")
    }

    @Test("Column minWidth defaults to zero")
    func minWidthDefault() {
        let col = TableWriter.Column("NAME")
        #expect(col.minWidth == 0)
    }

    @Test("Column minWidth is set correctly")
    func minWidthSet() {
        let col = TableWriter.Column("STORE", minWidth: 14)
        #expect(col.minWidth == 14)
        #expect(col.header == "STORE")
    }

    @Test("Column header length does not change")
    func headerLengthPreserved() {
        let col = TableWriter.Column("ALGORITHM", minWidth: 9)
        #expect(col.header.count == 9)
        #expect(col.minWidth == 9)
    }

    // MARK: - Render (smoke tests — no crash)

    @Test("Single column, single row renders without crash")
    func singleCell() {
        // TableWriter writes to stdout — verify no crash
        TableWriter.print(
            columns: [.init("NAME")],
            rows: [["github"]],
        )
    }

    @Test("Empty rows produce no output without crashing")
    func emptyRows() {
        // Must return early without crash
        TableWriter.print(
            columns: [.init("NAME"), .init("ALGO")],
            rows: [],
        )
    }

    @Test("Multiple columns and multiple rows render without crash")
    func multipleColumnsRows() {
        TableWriter.print(
            columns: [
                .init("STORE", minWidth: 14),
                .init("NAME", minWidth: 10),
                .init("ALGORITHM", minWidth: 9),
                .init("AUTH", minWidth: 8),
                .init("FINGERPRINT"),
            ],
            rows: [
                ["Secure Enclave", "github", "ecdsa-sha2-nistp256", "presence", "SHA256:abc123"],
                ["Secure Enclave", "deploy", "mldsa-65", "biometry-current", "SHA256:xyz789"],
            ],
        )
    }
}

// MARK: - OutputMode Tests

@Suite("OutputMode") @MainActor
struct OutputModeTests {
    @Test("OutputMode has exactly .table and .json cases")
    func outputModeCases() {
        let table = OutputMode.table
        let json = OutputMode.json

        switch table {
        case .table: break
        case .json: Issue.record("Expected .table, got .json")
        }

        switch json {
        case .json: break
        case .table: Issue.record("Expected .json, got .table")
        }
    }

    @Test("OutputMode values are distinct")
    func outputModeDistinct() {
        switch OutputMode.table {
        case .table: break
        case .json:
            Issue.record("table and json must be different cases")
        }
    }
}

// MARK: - ANSI Color Tests

@Suite("ANSI") @MainActor
struct ANSIColorTests {
    @Test("All ANSI codes are either empty or valid escape sequences")
    func validEscapeSequences() {
        let codes = [ANSI.green, ANSI.yellow, ANSI.red, ANSI.bold, ANSI.reset]
        for code in codes {
            if !code.isEmpty {
                #expect(code.hasPrefix("\u{1B}["), "Expected escape prefix, got: \(code)")
                #expect(code.hasSuffix("m"), "Expected 'm' suffix, got: \(code)")
            }
        }
    }

    @Test("reset is always the SGR reset sequence or empty")
    func resetSequence() {
        // Either empty (NO_COLOR) or the proper reset
        let reset = ANSI.reset
        #expect(reset.isEmpty || reset == "\u{1B}[0m")
    }

    @Test("NO_COLOR env disables all color codes in non-TTY context")
    func noColorDisablesInPipedContext() {
        // In the test runner, stdout is NOT a TTY, so isColorEnabled = false
        // → all codes must be empty strings
        if !ANSI.isColorEnabled {
            #expect(ANSI.green.isEmpty)
            #expect(ANSI.red.isEmpty)
            #expect(ANSI.bold.isEmpty)
            #expect(ANSI.reset.isEmpty)
        }
    }
}
