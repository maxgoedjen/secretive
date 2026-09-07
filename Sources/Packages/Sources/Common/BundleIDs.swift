import Foundation

extension Bundle {
    public static var agentBundleID: String {
        Bundle.main.bundleIdentifier!.replacingOccurrences(of: "Host", with: "SecretAgent")
    }

    public static var hostBundleID: String {
        Bundle.main.bundleIdentifier!.replacingOccurrences(of: "SecretAgent", with: "Host")
    }
}
