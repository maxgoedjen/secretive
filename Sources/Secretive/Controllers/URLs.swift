import Foundation

extension URL {

    static var agentHomeURL: URL {
        URL(fileURLWithPath: URL.homeDirectory.path().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID))
    }

    static var socketPath: String {
        URL.agentHomeURL.appendingPathComponent("socket.ssh").path()
    }
}
