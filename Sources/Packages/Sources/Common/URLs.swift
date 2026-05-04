import Foundation
import SSHProtocolKit
import SecretKit

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

    public static var publicKeyDirectory: URL {
        agentHomeURL.appending(component: "PublicKeys")
    }

    /// The path for a Secret's public key.
    /// - Parameter secret: The Secret to return the path for.
    /// - Returns: The path to the Secret's public key.
    /// - Warning: This method returning a path does not imply that a key has been written to disk already. This method only describes where it will be written to.
    public static func publicKeyPath<SecretType: Secret>(for secret: SecretType, in directory: URL) -> String {
        let keyWriter = OpenSSHPublicKeyWriter()
        let minimalHex = keyWriter.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        return directory.appending(component: "\(minimalHex).pub").path()
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

