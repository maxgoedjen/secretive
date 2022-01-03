import Foundation
import OSLog
import SecretKit

/// Controller responsible for writing public keys to disk, so that they're easily accessible by scripts.
public class PublicKeyFileStoreController {

    private let logger = Logger()
    private let directory = NSHomeDirectory().appending("/PublicKeys")

    /// Initializes a PublicKeyFileStoreController
    public init() {
    }

    /// Removes and recreates the directory used to store keys.
    public func clear() throws {
    }

    /// Writes out the keys specified to disk.
    /// - Parameter secrets: The Secrets to generate keys for.
    /// - Parameter clear: Whether or not the directory should be erased before writing keys.
    public func generatePublicKeys(for secrets: [AnySecret], clear: Bool = false) throws {
        logger.log("Writing public keys to disk")
        if clear {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: directory))
        }
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: directory), withIntermediateDirectories: false, attributes: nil)
        let keyWriter = OpenSSHKeyWriter()
        for secret in secrets {
            let path = path(for: secret)
            guard let data = keyWriter.openSSHString(secret: secret).data(using: .utf8) else { continue }
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
        logger.log("Finished writing public keys")
    }

    /// The path for a Secret's public key.
    /// - Parameter secret: The Secret to return the path for.
    /// - Returns: The path to the Secret's public key.
    /// - Warning: This method returning a path does not imply that a key has been written to disk already. This method only describes where it will be written to.
    func path(for secret: AnySecret) -> String {
        directory.appending("/").appending("\(secret.name.replacingOccurrences(of: " ", with: "-")).pub")
    }

}
