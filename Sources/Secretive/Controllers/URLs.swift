import Foundation

extension URL {

    static var agentHomeURL: URL {
        URL(fileURLWithPath: URL.homeDirectory.path().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID))
    }

    static var socketPath: String {
        URL.agentHomeURL.appendingPathComponent("socket.ssh").path()
    }

}

extension String {

    var normalizedPathAndFolder: (String, String) {
        // All foundation-based normalization methods replace this with the container directly.
        let processedPath = replacingOccurrences(of: "~", with: "/Users/\(NSUserName())")
        let url = URL(filePath: processedPath)
        let folder = url.deletingLastPathComponent().path()
        return (processedPath, folder)
    }

}
