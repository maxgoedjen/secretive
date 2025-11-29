import Foundation

extension URL {

    public static var agentHomeURL: URL {
        URL(fileURLWithPath: URL.homeDirectory.path().replacingOccurrences(of: Bundle.hostBundleID, with: Bundle.agentBundleID))
    }

    public static var socketPath: String {
        #if DEBUG
        URL.agentHomeURL.appendingPathComponent("socket-debug.ssh").path()
        #else
        URL.agentHomeURL.appendingPathComponent("socket.ssh").path()
        #endif
    }

}

extension String {

    public var normalizedPathAndFolder: (String, String) {
        // All foundation-based normalization methods replace this with the container directly.
        let processedPath = replacingOccurrences(of: "~", with: "/Users/\(NSUserName())")
        let url = URL(filePath: processedPath)
        let folder = url.deletingLastPathComponent().path()
        return (processedPath, folder)
    }

}
