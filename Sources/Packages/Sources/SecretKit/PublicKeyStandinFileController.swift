import Foundation
import OSLog

/// Controller responsible for writing public keys to disk, so that they're easily accessible by scripts.
public class PublicKeyFileStoreController {

    private let logger = Logger()
    private let directory: String
    private let keyWriter = OpenSSHKeyWriter()

    /// Initializes a PublicKeyFileStoreController.
    public init(homeDirectory: String) {
        directory = homeDirectory.appending("/PublicKeys")
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
    public func path<SecretType: Secret>(for secret: SecretType) -> String {
        let minimalHex = keyWriter.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        return directory.appending("/").appending("\(minimalHex).pub")
    }

}
