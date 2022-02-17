import Foundation


extension Bundle {
    public var agentBundleID: String {(self.bundleIdentifier?.replacingOccurrences(of: "Host", with: "SecretAgent"))!}
    public var hostBundleID: String {(self.bundleIdentifier?.replacingOccurrences(of: "SecretAgent", with: "Host"))!}
    public var updaterBundleID: String { "Z72PRUAWF6.com.maxgoedjen.SecretiveUpdater" }
}
