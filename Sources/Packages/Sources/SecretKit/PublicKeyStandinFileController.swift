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
    /// - Parameter clear: Whether or not any untracked files in the directory should be removed.
    public func generatePublicKeys(for secrets: [AnySecret], clear: Bool = false) throws {
        logger.log("Writing public keys to disk")
        if clear {
            let validPaths = Set(secrets.map { publicKeyPath(for: $0) }).union(Set(secrets.map { sshCertificatePath(for: $0) }))
            let untracked = Set(try FileManager.default.contentsOfDirectory(atPath: directory)
                .map { "\(directory)/\($0)" })
                .subtracting(validPaths)
            for path in untracked {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }
        }
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: directory), withIntermediateDirectories: false, attributes: nil)
        for secret in secrets {
            let path = publicKeyPath(for: secret)
            guard let data = keyWriter.openSSHString(secret: secret).data(using: .utf8) else { continue }
            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
        }
        logger.log("Finished writing public keys")
    }

    /// The path for a Secret's public key.
    /// - Parameter secret: The Secret to return the path for.
    /// - Returns: The path to the Secret's public key.
    /// - Warning: This method returning a path does not imply that a key has been written to disk already. This method only describes where it will be written to.
    public func publicKeyPath<SecretType: Secret>(for secret: SecretType) -> String {
        let minimalHex = keyWriter.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        return directory.appending("/").appending("\(minimalHex).pub")
    }

    /// Short-circuit check to ship enumerating a bunch of paths if there's nothing in the cert directory.
    public var hasAnyCertificates: Bool {
        do {
            return try FileManager.default
                .contentsOfDirectory(atPath: directory)
                .filter { $0.hasSuffix("-cert.pub") }
                .isEmpty == false
        } catch {
            return false
        }
    }

    /// The path for a Secret's SSH Certificate public key.
    /// - Parameter secret: The Secret to return the path for.
    /// - Returns: The path to the SSH Certificate public key.
    /// - Warning: This method returning a path does not imply that a key has a SSH certificates. This method only describes where it will be.
    public func sshCertificatePath<SecretType: Secret>(for secret: SecretType) -> String {
        let minimalHex = keyWriter.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        return directory.appending("/").appending("\(minimalHex)-cert.pub")
    }

}
