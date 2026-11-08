import Foundation

// MARK: - Command Router

/// Lightweight manual argument dispatcher. Zero external dependencies.
/// Follows the noun→verb convention: `secretive <noun> <verb> [args] [flags]`
enum CommandRouter {
    static func dispatch(_ args: [String]) async {
        let pos = positional(args: args)
        if pos.isEmpty {
            if flag("--version", in: args) || flag("-v", in: args) {
                VersionCommand.run(args)
                exit(ExitCode.ok.rawValue)
            }
            if flag("--help", in: args) || flag("-h", in: args) {
                printUsage()
                exit(ExitCode.ok.rawValue)
            }
        }

        guard let noun = pos.first else {
            printUsage()
            exit(ExitCode.usage.rawValue)
        }

        switch noun {
        case "key":
            await KeyCommands.dispatch(removeFirst(noun, from: args))
        case "cert":
            await CertCommands.dispatch(removeFirst(noun, from: args))
        case "agent":
            await AgentCommands.dispatch(removeFirst(noun, from: args))
        case "env":
            EnvCommand.run(removeFirst(noun, from: args))
        case "version":
            VersionCommand.run(removeFirst(noun, from: args))
        case "--help", "-h", "help":
            printUsage()
            exit(ExitCode.ok.rawValue)
        case "--version":
            VersionCommand.run([])
        default:
            let known = ["key", "cert", "agent", "env", "version", "help"]
            if let suggestion = suggest(command: noun, candidates: known) {
                exitWithStringError("unknown command '\(noun)'. Did you mean '\(suggestion)'?", code: .usage)
            } else {
                exitWithStringError("unknown command '\(noun)'", code: .usage)
            }
        }
    }

    static func suggest(command: String, candidates: [String]) -> String? {
        // Simple Levenshtein distance threshold
        var bestMatch: String? = nil
        var bestDistance = Int.max
        for candidate in candidates {
            let distance = levenshtein(a: command, b: candidate)
            if distance <= 2, distance < bestDistance {
                bestMatch = candidate
                bestDistance = distance
            }
        }
        return bestMatch
    }

    static func levenshtein(a: String, b: String) -> Int {
        if a == b {
            return 0
        }
        if a.isEmpty {
            return b.count
        }
        if b.isEmpty {
            return a.count
        }

        let a = Array(a)
        let b = Array(b)

        // Ensure target is the shorter array to constrain memory allocation to O(min(N, M))
        let (source, target) = a.count >= b.count ? (a, b) : (b, a)
        var row = Array(0...target.count)

        for (i, sourceChar) in source.enumerated() {
            var previousDiagonal = row[0]
            row[0] = i + 1

            for (j, targetChar) in target.enumerated() {
                let oldRowJ = row[j + 1]
                if sourceChar == targetChar {
                    row[j + 1] = previousDiagonal
                } else {
                    row[j + 1] = min(previousDiagonal, row[j], oldRowJ) + 1
                }
                previousDiagonal = oldRowJ
            }
        }
        return row[target.count]
    }

    static func removeFirst(_ target: String, from args: [String]) -> [String] {
        var copy = args
        if let idx = copy.firstIndex(of: target) {
            copy.remove(at: idx)
        }
        return copy
    }

    // MARK: - Argument Parsing Helpers

    /// Extracts the value for a flag like `--flag value`, `--flag=value`, or `-fValue`.
    /// Returns nil if the flag is absent or if the next argument is another flag.
    static func value(for flag: String, in args: [String]) -> String? {
        for (idx, arg) in args.enumerated() {
            if arg == flag, idx + 1 < args.count {
                let next = args[idx + 1]
                if !next.hasPrefix("-") {
                    return next
                }
            }
            if arg.hasPrefix("\(flag)=") {
                return String(arg.dropFirst(flag.count + 1))
            }
            // Support concatenated short option values (e.g. -oPath)
            if flag.count == 2, flag.hasPrefix("-"), !flag.hasPrefix("--"),
               arg.hasPrefix(flag), arg.count > 2, !arg.hasPrefix("--") {
                return String(arg.dropFirst(2))
            }
        }
        return nil
    }

    /// Returns true if the given boolean flag is present in args.
    static func flag(_ name: String, in args: [String]) -> Bool {
        args.contains(name)
    }

    /// Returns all positional arguments (args that are not flags or flag values).
    static func positional(args: [String]) -> [String] {
        let valueFlags: Set = ["--store", "--type", "--auth", "--attribution", "--name", "--shell", "--output", "-o"]
        var result: [String] = []
        var skipNext = false
        for (idx, arg) in args.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            if arg == "--" {
                if idx + 1 < args.count {
                    result.append(contentsOf: args[(idx + 1)...])
                }
                break
            }
            if arg.hasPrefix("-") {
                if valueFlags.contains(arg), idx + 1 < args.count, !args[idx + 1].hasPrefix("-") {
                    skipNext = true
                }
                continue
            }
            result.append(arg)
        }
        return result
    }

    // MARK: - Usage

    static func printUsage() {
        let usage = """
        \(ANSI.bold)Secretive CLI\(ANSI.reset)

          Manage SSH keys stored securely within the Mac Secure Enclave.

        \(ANSI.bold)USAGE\(ANSI.reset)

          secretive [options] <command> [subcommand] [args]

        \(ANSI.bold)COMMANDS\(ANSI.reset)

          Core
            key         Manage Secure Enclave keys (list, show, create, delete, rename)
            cert        Manage OpenSSH certificates (list, import, delete)
            agent       Manage the SecretAgent background service

          Utility
            env         Print shell environment configuration (SSH_AUTH_SOCK)
            version     Print version and Secure Enclave capabilities

        \(ANSI.bold)GLOBAL OPTIONS\(ANSI.reset)

            -h, --help  Output usage information
            --json      Format output as machine-readable JSON

        \(ANSI.bold)EXAMPLES\(ANSI.reset)

          – Create a new hardware-backed key and save the public key
            $ secretive key create github_key -o ~/.ssh/id_github.pub

          – List all keys stored in the Secure Enclave
            $ secretive key list

          – Export the public key of an existing key
            $ secretive key show github_key --public-key -o ~/.ssh/id_github.pub

          – Import an OpenSSH certificate
            $ secretive cert import ~/.ssh/id_github-cert.pub

          – Check the status of SecretAgent in JSON format
            $ secretive agent status --json

        For command-specific help, run `secretive <command> --help`
        """
        print(usage)
    }
}
