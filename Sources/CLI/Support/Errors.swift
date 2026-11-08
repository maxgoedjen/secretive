import Foundation

// MARK: - Exit Codes

/// POSIX sysexits.h + semantic extensions.
enum ExitCode: Int32 {
    case ok = 0
    case usage = 64 // EX_USAGE  — invalid arguments
    case dataError = 65 // EX_DATAERR — data format error
    case unavailable = 69 // EX_UNAVAILABLE — store not available
    case software = 70 // EX_SOFTWARE — internal error
    case cantCreate = 73 // EX_CANTCREAT — can't create output
    case noPerm = 77 // EX_NOPERM — permission denied (Keychain)
    case config = 78 // EX_CONFIG — configuration error
    case keyNotFound = 80 // Custom — key not found
    case ambiguous = 81 // Custom — ambiguous key match
    case agentNotRunning = 82 // Custom — agent not running
    case unsupported = 83 // Custom — operation not supported
}

// MARK: - CLI Error

/// Top-level CLI error type. All errors printed to stderr.
enum CLIError: Error, CustomStringConvertible {
    case usageError(String)
    case keyNotFound(String)
    case ambiguousKey(String, candidates: [String])
    case storeUnavailable(String)
    case secureEnclaveUnavailable
    case operationUnsupported(String)
    case agentNotRunning
    case keychainError(OSStatus)
    case ioError(String)
    case algorithmUnavailable(String)

    var description: String {
        switch self {
        case let .usageError(msg):
            return "error: \(msg)"
        case let .keyNotFound(id):
            return "error: no key found matching '\(id)'"
        case let .ambiguousKey(id, candidates):
            let list = candidates.map { "  \($0)" }.joined(separator: "\n")
            return "error: '\(id)' is ambiguous; matches:\n\(list)"
        case let .storeUnavailable(name):
            return "error: store '\(name)' is not available"
        case .secureEnclaveUnavailable:
            return "error: Secure Enclave is not available on this device"
        case let .operationUnsupported(msg):
            return "error: \(msg)"
        case .agentNotRunning:
            return "error: SecretAgent is not running — launch Secretive.app first"
        case let .keychainError(status):
            return "error: Keychain operation failed (OSStatus \(status))"
        case let .ioError(msg):
            return "error: I/O error — \(msg)"
        case let .algorithmUnavailable(algo):
            return "error: '\(algo)' requires macOS 26 or later"
        }
    }

    var exitCode: ExitCode {
        switch self {
        case .usageError: .usage
        case .keyNotFound: .keyNotFound
        case .ambiguousKey: .ambiguous
        case .storeUnavailable: .unavailable
        case .secureEnclaveUnavailable: .unavailable
        case .operationUnsupported: .unsupported
        case .agentNotRunning: .agentNotRunning
        case .keychainError: .noPerm
        case .ioError: .cantCreate
        case .algorithmUnavailable: .unavailable
        }
    }
}

// MARK: - Terminal Helpers

/// Writes a message to stderr.
func printError(_ message: String) {
    fputs(message + "\n", stderr)
}

/// Exits with an error. If --json is present globally, formats output as JSON to stdout.
func exitWithError(_ error: CLIError) -> Never {
    if CommandLine.arguments.contains("--json") {
        let jsonPayload: [String: Any] = [
            "error": [
                "code": error.exitCode.rawValue,
                "message": error.description.replacingOccurrences(of: "error: ", with: ""),
            ],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: jsonPayload, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            print(str) // JSON output goes strictly to stdout
        }
    } else {
        printError(ANSI.red + error.description + ANSI.reset)
    }
    exit(error.exitCode.rawValue)
}

/// Exits with a raw string error.
func exitWithStringError(_ message: String, code: ExitCode) -> Never {
    if CommandLine.arguments.contains("--json") {
        let jsonPayload: [String: Any] = [
            "error": [
                "code": code.rawValue,
                "message": message.replacingOccurrences(of: "error: ", with: ""),
            ],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: jsonPayload, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        let msg = message.hasPrefix("error:") ? message : "error: \(message)"
        printError(ANSI.red + msg + ANSI.reset)
    }
    exit(code.rawValue)
}
