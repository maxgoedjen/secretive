import CryptoKit
import Foundation
import SecretKit
import SecureEnclaveSecretKit

// MARK: - Version Command

/// Outputs build and capability information.
enum VersionCommand {
    /// These constants will be populated from Info.plist in the signed bundle.
    /// For SPM builds without a bundle, we fall back to compile-time defaults.
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    static func run(_ args: [String]) {
        let jsonMode = CommandRouter.flag("--json", in: args)
        let seAvailable = CryptoKit.SecureEnclave.isAvailable

        let pqAlgos: [String] = if #available(macOS 26, *) {
            ["mldsa-65", "mldsa-87"]
        } else {
            []
        }

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        if jsonMode {
            let info = VersionInfo(
                version: appVersion,
                build: buildNumber,
                os_version: osVersion,
                secure_enclave_available: seAvailable,
                post_quantum_algorithms: pqAlgos,
            )
            JSONWriter.print(info)
        } else {
            print("secretive \(appVersion) (build \(buildNumber))")
            print("macOS \(osVersion) (Secure Enclave: \(seAvailable ? "available" : "unavailable"))")
            if pqAlgos.isEmpty {
                print("Post-quantum algorithms: none (requires macOS 26+)")
            } else {
                print("Post-quantum algorithms: \(pqAlgos.joined(separator: ", "))")
            }
        }
    }
}

// MARK: - JSON Schema

struct VersionInfo: Encodable {
    let version: String
    let build: String
    let os_version: String
    let secure_enclave_available: Bool
    let post_quantum_algorithms: [String]
}
