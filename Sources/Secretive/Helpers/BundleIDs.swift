import Foundation


extension Bundle {
    public var agentBundleID: String { "Z72PRUAWF6.com.maxgoedjen.Secretive.SecretAgent" }
    public var hostBundleID: String {(self.bundleIdentifier?.replacingOccurrences(of: "SecretAgent", with: "Host"))!}
}
