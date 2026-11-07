import Foundation

// MARK: - JSON Writer

/// Writes Encodable values as pretty-printed JSON to stdout.
enum JSONWriter {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    /// Encodes `value` as JSON and writes it to stdout.
    static func print(_ value: some Encodable) {
        do {
            let data = try encoder.encode(value)
            guard let string = String(data: data, encoding: .utf8) else {
                exitWithError(.ioError("Failed to encode JSON output"))
            }
            Swift.print(string)
        } catch {
            exitWithError(.ioError("JSON encoding failed: \(error)"))
        }
    }
}
