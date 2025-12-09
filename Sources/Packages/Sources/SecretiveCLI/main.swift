import Foundation
import Darwin
import SecretAgentKit
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Common
import OSLog

@main
struct SecretiveCLI {
    private static let logger = Logger(subsystem: "com.maxgoedjen.secretive.cli", category: "CLI")
    
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        
        guard let command = args.first else {
            printUsage()
            exit(1)
        }
        
        do {
            switch command {
            case "agent":
                try await handleAgentCommand(args: Array(args.dropFirst()))
            case "key":
                try await handleKeyCommand(args: Array(args.dropFirst()))
            case "help", "--help", "-h":
                printUsage()
            default:
                print("Unknown command: \(command)")
                printUsage()
                exit(1)
            }
        } catch {
            logger.error("Error: \(error.localizedDescription)")
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func printUsage() {
        print("""
        Secretive CLI - Manage SSH keys with Secure Enclave
        
        Usage: secretive-cli <command> [options]
        
        Commands:
          agent <subcommand>    Manage SSH agent
            install             Install agent as launchd service
            uninstall           Uninstall agent from launchd
            start               Start the agent service
            stop                Stop the agent service
            status              Check agent status
            run                 Run agent in foreground (for testing)
        
          key <subcommand>      Manage SSH keys
            generate [name]     Generate a new key (default: "Secretive Key")
            list                List all keys
            show <name>         Show public key for a key by name
            delete <name>       Delete a key by name
            update <name>       Update key attributes (name/authentication)
        
          help                  Show this help message
        """)
    }
}

// MARK: - Agent Commands

extension SecretiveCLI {
    
    static func handleAgentCommand(args: [String]) async throws {
        guard let subcommand = args.first else {
            print("Agent subcommand required: install, uninstall, start, stop, status, or run")
            exit(1)
        }
        
        switch subcommand {
        case "install":
            try await installAgent()
        case "uninstall":
            try await uninstallAgent()
        case "start":
            try await startAgent()
        case "stop":
            try await stopAgent()
        case "status":
            try await checkAgentStatus()
        case "run":
            try await runAgent()
        default:
            print("Unknown agent subcommand: \(subcommand)")
            exit(1)
        }
    }
    
    static func installAgent() async throws {
        let plistPath = launchdPlistPath
        let plistDir = (plistPath as NSString).deletingLastPathComponent
        
        // Create directory if needed
        try FileManager.default.createDirectory(atPath: plistDir, withIntermediateDirectories: true)
        
        // Get the CLI binary path
        guard let cliPath = Bundle.main.executablePath else {
            throw CLIError("Could not determine CLI binary path")
        }
        
        // Create plist content
        let plist: [String: Any] = [
            "Label": launchdServiceLabel,
            "ProgramArguments": [cliPath, "agent", "run"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "/dev/null",
            "StandardErrorPath": "/dev/null",
            "EnvironmentVariables": [
                "SSH_AUTH_SOCK": socketPath
            ]
        ]
        
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: URL(fileURLWithPath: plistPath))
        
        // Bootstrap the service
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootstrap", "gui/\(getuid())", plistPath]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw CLIError("Failed to install agent: launchctl bootstrap returned \(process.terminationStatus)")
        }
        
        print("Agent installed successfully")
    }
    
    static func uninstallAgent() async throws {
        let plistPath = launchdPlistPath
        
        // Unbootstrap the service
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["bootout", "gui/\(getuid())", launchdServiceLabel]
        
        try process.run()
        process.waitUntilExit()
        
        // Remove plist file if it exists
        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }
        
        print("Agent uninstalled successfully")
    }
    
    static func startAgent() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kickstart", "gui/\(getuid())/\(launchdServiceLabel)"]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw CLIError("Failed to start agent: launchctl kickstart returned \(process.terminationStatus)")
        }
        
        print("Agent started")
    }
    
    static func stopAgent() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["kill", "gui/\(getuid())/\(launchdServiceLabel)"]
        
        try process.run()
        process.waitUntilExit()
        
        print("Agent stopped")
    }
    
    static func checkAgentStatus() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", launchdServiceLabel]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus == 0 && !output.isEmpty {
            print("Agent is running")
            print(output)
        } else {
            print("Agent is not running")
        }
    }
    
    static func runAgent() async throws {
        logger.info("Starting SSH agent")
        
        // Set up store list
        let storeList: SecretStoreList = await MainActor.run {
            let list = SecretStoreList()
            let cryptoKit = SecureEnclave.Store()
            let migrator = SecureEnclave.CryptoKitMigrator()
            try? migrator.migrate(to: cryptoKit)
            list.add(store: cryptoKit)
            list.add(store: SmartCard.Store())
            return list
        }
        
        // Create agent (no witness for CLI)
        let agent = Agent(storeList: storeList, witness: nil)
        
        // Set up socket controller
        let socket = SocketController(path: socketPath)
        
        // Set up input parser (use direct parser, not XPC)
        let parser = SSHAgentInputParser()
        
        logger.info("SSH agent listening on \(socketPath)")
        print("SSH agent running on \(socketPath)")
        print("Set SSH_AUTH_SOCK=\(socketPath) to use this agent")
        
        // Handle sessions
        for await session in socket.sessions {
            Task {
                do {
                    for await message in session.messages {
                        let request = try parser.parse(data: message)
                        let response = await agent.handle(request: request, provenance: session.provenance)
                        try await MainActor.run {
                            try session.write(response)
                        }
                    }
                } catch {
                    logger.error("Session error: \(error.localizedDescription)")
                    try? session.close()
                }
            }
        }
    }
    
    // MARK: - Agent Paths
    
    static var socketPath: String {
        // Use the same socket path as the GUI app
        // This matches URL.socketPath from Common module, which constructs:
        // ~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let containerPath = "\(home)/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data"
        #if DEBUG
        return "\(containerPath)/socket-debug.ssh"
        #else
        return "\(containerPath)/socket.ssh"
        #endif
    }
    
    static var launchdServiceLabel: String {
        "com.maxgoedjen.secretive.cli"
    }
    
    static var launchdPlistPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/LaunchAgents/\(launchdServiceLabel).plist"
    }
}

// MARK: - Key Commands

extension SecretiveCLI {
    
    static func handleKeyCommand(args: [String]) async throws {
        guard let subcommand = args.first else {
            print("Key subcommand required: generate, list, show, delete, or update")
            exit(1)
        }
        
        // Set up store list
        let storeList: SecretStoreList = await MainActor.run {
            let list = SecretStoreList()
            let cryptoKit = SecureEnclave.Store()
            let migrator = SecureEnclave.CryptoKitMigrator()
            try? migrator.migrate(to: cryptoKit)
            list.add(store: cryptoKit)
            list.add(store: SmartCard.Store())
            return list
        }
        
        guard let modifiableStore = await storeList.modifiableStore else {
            throw CLIError("No modifiable store available")
        }
        
        switch subcommand {
        case "generate":
            let name = args.count > 1 ? args[1] : "Secretive Key"
            try await generateKey(name: name, store: modifiableStore)
        case "list":
            try await listKeys(storeList: storeList)
        case "show":
            guard args.count > 1 else {
                print("Key name required for show command")
                exit(1)
            }
            try await showKey(name: args[1], storeList: storeList)
        case "delete":
            guard args.count > 1 else {
                print("Key name required for delete command")
                exit(1)
            }
            try await deleteKey(name: args[1], store: modifiableStore, storeList: storeList)
        case "update":
            guard args.count > 1 else {
                print("Key name required for update command")
                exit(1)
            }
            try await updateKey(name: args[1], store: modifiableStore, storeList: storeList)
        default:
            print("Unknown key subcommand: \(subcommand)")
            exit(1)
        }
    }
    
    static func generateKey(name: String, store: AnySecretStoreModifiable) async throws {
        let attributes = Attributes(
            keyType: .ecdsa256,
            authentication: .presenceRequired,
            publicKeyAttribution: nil
        )
        
        let secret = try await store.create(name: name, attributes: attributes)
        let writer = OpenSSHPublicKeyWriter()
        let publicKeyString = writer.openSSHString(secret: secret)
        
        print("Key '\(name)' generated successfully")
        print("Public key:")
        print(publicKeyString)
    }
    
    static func listKeys(storeList: SecretStoreList) async throws {
        let secrets = await storeList.allSecrets
        
        if secrets.isEmpty {
            print("No keys found")
            return
        }
        
        print("Keys:")
        for secret in secrets {
            let authIndicator = secret.authenticationRequirement.required ? "🔒" : "🔓"
            print("  \(authIndicator) \(secret.name) (\(secret.keyType.description))")
        }
    }
    
    static func showKey(name: String, storeList: SecretStoreList) async throws {
        let secrets = await storeList.allSecrets
        guard let secret = secrets.first(where: { $0.name == name }) else {
            throw CLIError("Key '\(name)' not found")
        }
        
        let writer = OpenSSHPublicKeyWriter()
        let publicKeyString = writer.openSSHString(secret: secret)
        
        print("Public key for '\(name)':")
        print(publicKeyString)
        print("\nFingerprints:")
        print("  SHA256: \(writer.openSSHSHA256Fingerprint(secret: secret))")
        print("  MD5:    \(writer.openSSHMD5Fingerprint(secret: secret))")
    }
    
    static func deleteKey(name: String, store: AnySecretStoreModifiable, storeList: SecretStoreList) async throws {
        let secrets = await storeList.allSecrets
        guard let secret = secrets.first(where: { $0.name == name }) else {
            throw CLIError("Key '\(name)' not found")
        }
        
        print("Deleting key '\(name)'...")
        try await store.delete(secret: secret)
        print("Key '\(name)' deleted successfully")
    }
    
    static func updateKey(name: String, store: AnySecretStoreModifiable, storeList: SecretStoreList) async throws {
        let secrets = await storeList.allSecrets
        guard let secret = secrets.first(where: { $0.name == name }) else {
            throw CLIError("Key '\(name)' not found")
        }
        
        // For now, just update the name (attributes can't be changed after creation)
        // In a full implementation, you might want to add prompts for new name
        print("Note: Key attributes cannot be changed after creation.")
        print("Current key: \(secret.name)")
        print("To rename, use: secretive-cli key delete '\(name)' && secretive-cli key generate '<new-name>'")
    }
}

// MARK: - Errors

struct CLIError: Error, CustomStringConvertible {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var description: String {
        message
    }
}

