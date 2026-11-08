import Foundation

// MARK: - Table Writer

/// Renders tabular data to stdout with auto-sized column widths.
enum TableWriter {
    // MARK: - Column Definition

    struct Column {
        let header: String
        let minWidth: Int

        init(_ header: String, minWidth: Int = 0) {
            self.header = header
            self.minWidth = minWidth
        }
    }

    // MARK: - Render

    /// Prints a table to stdout.
    /// - Parameters:
    ///   - columns: Ordered column definitions.
    ///   - rows: Row data. Each row must have the same count as `columns`.
    static func print(columns: [Column], rows: [[String]]) {
        guard !rows.isEmpty else { return }

        // Compute column widths: max(header, min, max cell content)
        let widths = columns.enumerated().map { idx, col in
            max(col.header.count, col.minWidth, rows.map { $0[idx].count }.max() ?? 0)
        }

        // HashiCorp Vault style headers with individual underlines
        let headerRow = columns.enumerated().map { idx, col in
            col.header.padding(toLength: widths[idx], withPad: " ", startingAt: 0)
        }.joined(separator: "  ")

        let underlineRow = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")

        Swift.print(ANSI.bold + headerRow + ANSI.reset)
        Swift.print(underlineRow)

        for row in rows {
            let line = row.enumerated().map { idx, cell in
                cell.padding(toLength: widths[idx], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
            Swift.print(line)
        }
    }
}
