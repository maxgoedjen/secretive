import AppKit
import Foundation

// MARK: - Agent Commands

/// Handles all `secretive agent <verb>` subcommands.
enum AgentCommands {
    static func dispatch(_ args: [String]) async {
        if CommandRouter.flag("--help", in: args) || CommandRouter.flag("-h", in: args) {
            printAgentUsage()
            exit(ExitCode.ok.rawValue)
        }

        let pos = CommandRouter.positional(args: args)
        guard let verb = pos.first else {
            printAgentUsage()
            exit(ExitCode.usage.rawValue)
        }
        let rest = CommandRouter.removeFirst(verb, from: args)
        switch verb {
        case "status":
            agentStatus(rest)
        case "--help", "-h":
            printAgentUsage()
            exit(ExitCode.ok.rawValue)
        default:
            exitWithStringError("unknown agent verb '\(verb)'", code: .usage)
        }
    }

    // MARK: - agent status

    static func agentStatus(_ args: [String]) {
        let jsonMode = CommandRouter.flag("--json", in: args)
        let agentBundleID = "com.maxgoedjen.Secretive.SecretAgent"

        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: agentBundleID,
        )
        let running = !apps.isEmpty
        let pid = apps.first.map { Int($0.processIdentifier) }

        let socketPath = StoreProvider.socketPath
        let socketExists = FileManager.default.fileExists(atPath: socketPath)

        // Count keys via agent socket if available
        var keysLoaded: Int? = nil
        if socketExists, let keyCount = countKeysViaSocket(socketPath: socketPath) {
            keysLoaded = keyCount
        }

        if jsonMode {
            let status = AgentStatus(
                running: running,
                pid: pid ?? nil,
                socket_path: socketPath,
                socket_exists: socketExists,
                keys_loaded: keysLoaded,
            )
            JSONWriter.print(status)
        } else {
            let runningStr = running
                ? "\(ANSI.green)running\(ANSI.reset) (pid \(pid.map(String.init) ?? "?"))"
                : "\(ANSI.red)not running\(ANSI.reset)"
            let socketStr = socketExists
                ? "\(ANSI.green)✓\(ANSI.reset) \(socketPath)"
                : "\(ANSI.red)✗\(ANSI.reset) \(socketPath)"
            let keysStr = keysLoaded.map { String($0) } ?? "—"
            print("""
            Agent:   \(runningStr)
            Socket:  \(socketStr)
            Keys:    \(keysStr)
            """)

            if !running {
                exit(ExitCode.agentNotRunning.rawValue)
            }
        }
    }

    // MARK: - SSH Agent Socket Query

    /// Attempts to list identities via the SSH agent socket protocol.
    /// Returns nil if the socket is unavailable or communication fails.
    private static func countKeysViaSocket(socketPath: String) -> Int? {
        try? SafePosixSocket.requestIdentities(socketPath: socketPath).count
    }

    static func printAgentUsage() {
        let usage = """
        Usage: secretive agent <subcommand> [args] [flags]

          Check the status of the SecretAgent background service.

        Subcommands:
            status      Show whether SecretAgent is running

        Options:
            -h, --help  Print this help output
            --json      Format output as JSON
        """
        print(usage)
    }
}

// MARK: - JSON Schema

struct AgentStatus: Encodable {
    let running: Bool
    let pid: Int?
    let socket_path: String
    let socket_exists: Bool
    let keys_loaded: Int?
}
