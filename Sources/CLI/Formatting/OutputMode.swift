import Darwin
import Foundation

// MARK: - Output Mode

/// Whether output should be a human-readable table or machine-parseable JSON.
enum OutputMode {
    case table
    case json
}

// MARK: - TTY Detection

/// Returns true when stdout is connected to a terminal (not piped / redirected).
var isStdoutTTY: Bool {
    isatty(STDOUT_FILENO) != 0
}

/// Returns true when stdin is connected to a terminal (not piped / redirected).
var isStdinTTY: Bool {
    isatty(STDIN_FILENO) != 0
}

// MARK: - ANSI Colors

/// Minimal ANSI color support; automatically disabled when stdout is not a TTY
/// or when the standard NO_COLOR environment variable is set.
enum ANSI {
    static var isColorEnabled: Bool {
        isStdoutTTY && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    }

    static var green: String {
        isColorEnabled ? "\u{1B}[32m" : ""
    }

    static var yellow: String {
        isColorEnabled ? "\u{1B}[33m" : ""
    }

    static var red: String {
        isColorEnabled ? "\u{1B}[31m" : ""
    }

    static var bold: String {
        isColorEnabled ? "\u{1B}[1m" : ""
    }

    static var reset: String {
        isColorEnabled ? "\u{1B}[0m" : ""
    }
}
