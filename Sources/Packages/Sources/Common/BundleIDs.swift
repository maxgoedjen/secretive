import Foundation

extension Bundle {
    static func replacingLastBundleComponent(in bundleID: String, with replacement: String) -> String {
        guard let separator = bundleID.lastIndex(of: ".") else {
            preconditionFailure("Expected a bundle identifier with at least two components.")
        }

        return "\(bundleID[..<separator]).\(replacement)"
    }

    private static var mainBundleID: String {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("Expected the main bundle to have a bundle identifier.")
        }

        return bundleIdentifier
    }

    public static var agentBundleID: String {
        replacingLastBundleComponent(in: mainBundleID, with: "SecretAgent")
    }

    public static var hostBundleID: String {
        replacingLastBundleComponent(in: mainBundleID, with: "Host")
    }

    public static var secretAgentInputParserServiceBundleID: String {
        replacingLastBundleComponent(in: mainBundleID, with: "SecretAgentInputParser")
    }

    public static var secretiveUpdaterServiceBundleID: String {
        replacingLastBundleComponent(in: mainBundleID, with: "SecretiveUpdater")
    }
}
