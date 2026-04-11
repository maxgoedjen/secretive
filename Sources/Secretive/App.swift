import SwiftUI
import AppKit
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import Brief
import Common

@main
struct Secretive: App {
    
    @Environment(\.agentLaunchController) var agentLaunchController
    @Environment(\.justUpdatedChecker) var justUpdatedChecker

    init() {
        let cliInvocation: SecretiveCLIInvocation
        do {
            cliInvocation = try SecretiveCLIInvocation.parse(arguments: Array(ProcessInfo.processInfo.arguments.dropFirst()))
        } catch {
            Self.writeCLIError(error.localizedDescription)
            exit(1)
        }

        switch cliInvocation {
        case .none:
            break
        case .help:
            Self.writeCLIOutput(SecretiveCLIInvocation.usage)
            exit(0)
        case .createSecret,
                .installAgent,
                .uninstallAgent,
                .agentStatus,
                .socketPath,
                .printIntegration:
            NSApplication.shared.setActivationPolicy(.prohibited)
            Task { @MainActor in
                let exitCode = await Self.runCLI(invocation: cliInvocation)
                exit(Int32(exitCode))
            }
        }
    }

    @SceneBuilder var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(EnvironmentValues._secretStoreList)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task {
                        @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
                        @AppStorage("explicitlyDisabled") var explicitlyDisabled = false
                        guard hasRunSetup && !explicitlyDisabled else { return }
                        agentLaunchController.check()
                        guard !agentLaunchController.developmentBuild else { return }
                        if justUpdatedChecker.justUpdatedBuild || !agentLaunchController.running {
                            // Relaunch the agent, since it'll be running from earlier update still
                            try await agentLaunchController.forceLaunch()
                        }
                    }
                }
        }
        .commands {
            AppCommands()
        }
        WindowGroup(id: String(describing: IntegrationsView.self)) {
            IntegrationsView()
        }
        .windowResizability(.contentMinSize)
        WindowGroup(id: String(describing: AboutView.self)) {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }

}

extension Secretive {

    @MainActor static func runCLI(invocation: SecretiveCLIInvocation) async -> Int {
        switch invocation {
        case let .createSecret(command):
            return await runCreateSecretCLI(command: command)
        case .installAgent:
            return await runInstallAgentCLI()
        case .uninstallAgent:
            return await runUninstallAgentCLI()
        case .agentStatus:
            return runAgentStatusCLI()
        case .socketPath:
            writeCLIOutput(URL.socketPath)
            return 0
        case let .printIntegration(command):
            writeCLIOutput(integrationInstructions(for: command.tool))
            return 0
        case .help:
            writeCLIOutput(SecretiveCLIInvocation.usage)
            return 0
        case .none:
            return 0
        }
    }

    @MainActor private static func runCreateSecretCLI(command: SecretiveCLIInvocation.CreateSecret) async -> Int {
        let store = SecureEnclave.Store()
        guard store.isAvailable else {
            writeCLIError("Secure Enclave is not available on this Mac.")
            return 1
        }

        guard store.supportedKeyTypes.available.contains(command.keyType) else {
            let available = store.supportedKeyTypes.available.map(\.description).joined(separator: ", ")
            writeCLIError("Key type '\(command.keyType)' is not available on this macOS version. Available key types: \(available).")
            return 1
        }

        do {
            let secret = try await store.create(name: command.name, attributes: command.attributes)
            writeCLIOutput(
                """
                id: \(secret.id)
                name: \(secret.name)
                protection-level: \(command.protectionLevel.rawValue)
                key-type: \(secret.keyType)
                key-attribution: \(secret.publicKeyAttribution ?? "")
                """
            )
            return 0
        } catch {
            writeCLIError(describeCLIError(error))
            return 1
        }
    }

    @MainActor private static func runInstallAgentCLI() async -> Int {
        let controller = AgentLaunchController()
        do {
            try await controller.install()
            UserDefaults.standard.set(true, forKey: CLIConstants.setupCompleteKey)
            UserDefaults.standard.set(false, forKey: CLIConstants.explicitlyDisabledKey)
            controller.check()
            writeCLIOutput(
                """
                installed: true
                running: \(controller.running)
                setup-complete: true
                socket-path: \(URL.socketPath)
                """
            )
            return controller.running ? 0 : 1
        } catch {
            writeCLIError(describeCLIError(error))
            return 1
        }
    }

    @MainActor private static func runUninstallAgentCLI() async -> Int {
        let controller = AgentLaunchController()
        do {
            UserDefaults.standard.set(true, forKey: CLIConstants.explicitlyDisabledKey)
            try await controller.uninstall()
            controller.check()
            writeCLIOutput(
                """
                installed: false
                running: \(controller.running)
                explicitly-disabled: true
                """
            )
            return controller.running ? 1 : 0
        } catch {
            writeCLIError(describeCLIError(error))
            return 1
        }
    }

    @MainActor private static func runAgentStatusCLI() -> Int {
        let controller = AgentLaunchController()
        controller.check()

        let setupComplete = UserDefaults.standard.bool(forKey: CLIConstants.setupCompleteKey)
        let explicitlyDisabled = UserDefaults.standard.bool(forKey: CLIConstants.explicitlyDisabledKey)

        var lines = [
            "running: \(controller.running)",
            "setup-complete: \(setupComplete)",
            "explicitly-disabled: \(explicitlyDisabled)",
            "socket-path: \(URL.socketPath)",
        ]

        if let process = controller.process, let bundleURL = process.bundleURL {
            lines.append("agent-path: \(bundleURL.path())")
            if let version = Bundle(url: bundleURL)?.infoDictionary?["CFBundleShortVersionString"] as? String {
                lines.append("agent-version: \(version)")
            }
        }

        writeCLIOutput(lines.joined(separator: "\n"))
        return 0
    }

    private static func integrationInstructions(for tool: SecretiveCLIInvocation.PrintIntegration.Tool) -> String {
        switch tool {
        case .ssh:
            """
            # ~/.ssh/config
            Host *
            \tIdentityAgent \(URL.socketPath)
            """
        case .zsh:
            """
            # ~/.zshrc
            export SSH_AUTH_SOCK=\(URL.socketPath)
            """
        case .bash:
            """
            # ~/.bashrc
            export SSH_AUTH_SOCK=\(URL.socketPath)
            """
        case .fish:
            """
            # ~/.config/fish/config.fish
            set -x SSH_AUTH_SOCK \(URL.socketPath)
            """
        }
    }

    private static func describeCLIError(_ error: Error) -> String {
        if let keychainError = error as? KeychainError, let statusCode = keychainError.statusCode {
            return "Keychain operation failed with status \(statusCode)."
        }

        let nsError = error as NSError
        let localizedDescription = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !localizedDescription.isEmpty {
            return localizedDescription
        }

        return String(describing: error)
    }

    static func writeCLIOutput(_ text: String) {
        FileHandle.standardOutput.write(Data((text + "\n").utf8))
    }

    static func writeCLIError(_ text: String) {
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}

private enum CLIConstants {
    static let setupCompleteKey = "defaultsHasRunSetup"
    static let explicitlyDisabledKey = "explicitlyDisabled"
}

extension Secretive {

    struct AppCommands: Commands {

        @Environment(\.openWindow) var openWindow
        @Environment(\.openURL) var openURL
        @FocusedValue(\.showCreateSecret) var showCreateSecret

        var body: some Commands {
            CommandGroup(replacing: .appInfo) {
                Button(.aboutMenuBarTitle, systemImage: "info.circle") {
                    openWindow(id: String(describing: AboutView.self))
                }
            }
            CommandGroup(before: CommandGroupPlacement.appSettings) {
                Button(.integrationsMenuBarTitle, systemImage: "app.connected.to.app.below.fill") {
                    openWindow(id: String(describing: IntegrationsView.self))
                }
            }
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button(.appMenuNewSecretButton, systemImage: "plus") {
                    showCreateSecret?()
                }
                .keyboardShortcut(KeyboardShortcut(KeyEquivalent("N"), modifiers: [.command, .shift]))
                .disabled(showCreateSecret?.isEnabled == false)
            }
            CommandGroup(replacing: .help) {
                Button(.appMenuHelpButton) {
                    openURL(Constants.helpURL)
                }
            }
            SidebarCommands()
        }
    }

}

private enum Constants {
    static let helpURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md")!
}


extension EnvironmentValues {

    // This is injected through .environment modifier below instead of @Entry for performance reasons (basially, restrictions around init/mainactor causing delay in loading secrets/"empty screen" blip).
    @MainActor fileprivate static let _secretStoreList: SecretStoreList = {
        let list = SecretStoreList()
        let cryptoKit = SecureEnclave.Store()
        let migrator = SecureEnclave.CryptoKitMigrator()
        try? migrator.migrate(to: cryptoKit)
        list.add(store: cryptoKit)
        list.add(store: SmartCard.Store())
        return list
    }()

    private static let _agentLaunchController = AgentLaunchController()
    @Entry var agentLaunchController: any AgentLaunchControllerProtocol = _agentLaunchController
    private static let _updater: any UpdaterProtocol = {
        @AppStorage("defaultsHasRunSetup") var hasRunSetup = false
        return Updater(checkOnLaunch: hasRunSetup)
    }()
    @Entry var updater: any UpdaterProtocol = _updater

    private static let _justUpdatedChecker = JustUpdatedChecker()
    @Entry var justUpdatedChecker: any JustUpdatedCheckerProtocol = _justUpdatedChecker

    @MainActor var secretStoreList: SecretStoreList {
        EnvironmentValues._secretStoreList
    }
}

extension FocusedValues {
    @Entry var showCreateSecret: OpenSheet?
}

final class OpenSheet {

    let closure: () -> Void
    let isEnabled: Bool

    init(isEnabled: Bool = true, closure: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.closure = closure
    }

    func callAsFunction() {
        closure()
    }

}
