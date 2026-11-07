import Foundation

// MARK: - Entry Point

/// Main entry point for the Secretive CLI.
/// Uses @MainActor isolation to comply with SecureEnclave.Store and SmartCard.Store
/// which require @MainActor for all property access (Swift 6 strict concurrency).
@main
struct SecretiveCLI {
    @MainActor static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        await CommandRouter.dispatch(args)
    }
}
