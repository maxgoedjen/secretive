import Foundation
import AppKit
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Common
import OSLog

@main
struct SecretiveCLI {
    private static let logger = Logger(subsystem: "com.cursorinternal.secretive.cli", category: "CLI")
    
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
          agent status          Check if Secretive's SSH agent is running
          agent start           Start Secretive's SSH agent
        
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
    
    private static let agentBundleID = "com.cursorinternal.Secretive.SecretAgent"
    private static let secretiveBundleID = "com.cursorinternal.Secretive.Host"
    
    static func handleAgentCommand(args: [String]) async throws {
        guard let subcommand = args.first else {
            print("Agent subcommand required: status, start")
            exit(1)
        }
        
        switch subcommand {
        case "status":
            try await checkAgentStatus()
        case "start":
            try await startAgent()
        default:
            print("Unknown agent subcommand: \(subcommand)")
            print("Available: status, start")
            exit(1)
        }
    }
    
    static func checkAgentStatus() async throws {
        // Check if the main Secretive app's SecretAgent is running
        let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleID)
        
        if let agent = runningAgents.first {
            print("Secretive agent is running")
            if let url = agent.bundleURL {
                print("  Path: \(url.path)")
            }
            print("  PID: \(agent.processIdentifier)")
            
            // Also check socket
            let socketPath = URL.socketPath
            if FileManager.default.fileExists(atPath: socketPath) {
                print("  Socket: \(socketPath)")
            }
        } else {
            print("Secretive agent is not running")
            print("Run 'secretive agent start' to start it")
        }
    }
    
    static func startAgent() async throws {
        // Check if already running
        let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleID)
        if !runningAgents.isEmpty {
            print("Secretive agent is already running")
            return
        }
        
        // Find the SecretAgent app inside the installed Secretive app
        guard let agentURL = findSecretAgentApp() else {
            throw CLIError("Could not find Secretive.app. Please ensure Secretive is installed in /Applications or ~/Applications.")
        }
        
        print("Starting Secretive agent...")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        
        do {
            try await NSWorkspace.shared.openApplication(at: agentURL, configuration: config)
            // Give it a moment to start
            try await Task.sleep(for: .seconds(1))
            
            // Verify it started
            let agents = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleID)
            if !agents.isEmpty {
                print("Secretive agent started successfully")
            } else {
                print("Warning: Agent may not have started. Check Secretive.app for details.")
            }
        } catch {
            throw CLIError("Failed to start agent: \(error.localizedDescription)")
        }
    }
    
    private static func findSecretAgentApp() -> URL? {
        let fileManager = FileManager.default
        
        // Possible locations for Secretive.app
        let searchPaths = [
            "/Applications/Secretive.app",
            "\(fileManager.homeDirectoryForCurrentUser.path)/Applications/Secretive.app"
        ]
        
        for path in searchPaths {
            let secretiveURL = URL(fileURLWithPath: path)
            let agentURL = secretiveURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
            if fileManager.fileExists(atPath: agentURL.path) {
                return agentURL
            }
        }
        
        // Also try to find via Launch Services
        if let secretiveURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: secretiveBundleID) {
            let agentURL = secretiveURL.appendingPathComponent("Contents/Library/LoginItems/SecretAgent.app")
            if fileManager.fileExists(atPath: agentURL.path) {
                return agentURL
            }
        }
        
        return nil
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

