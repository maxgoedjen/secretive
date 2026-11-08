import Foundation

// MARK: - Env Command

/// Outputs shell environment configuration for Secretive's SSH agent socket.
enum EnvCommand {
    enum Shell: String {
        case zsh, bash, fish
    }

    static func run(_ args: [String]) {
        let shellOverride = CommandRouter.value(for: "--shell", in: args)
        let shell = detectShell(override: shellOverride)
        let socketPath = StoreProvider.socketPath

        switch shell {
        case .fish:
            print("set -x SSH_AUTH_SOCK \(socketPath)")
        case .zsh, .bash:
            print("export SSH_AUTH_SOCK=\(socketPath)")
        }
    }

    private static func detectShell(override: String?) -> Shell {
        if let raw = override {
            guard let shell = Shell(rawValue: raw.lowercased()) else {
                exitWithStringError("unsupported shell '\(raw)'; choose from: zsh, bash, fish", code: .usage)
            }
            return shell
        }

        // Auto-detect from $SHELL
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? ""
        if shellPath.hasSuffix("fish") {
            return .fish
        }
        if shellPath.hasSuffix("zsh") {
            return .zsh
        }
        // Default to bash for unknown shells
        return .bash
    }
}
