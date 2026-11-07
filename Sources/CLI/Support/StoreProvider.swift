import Foundation
import SecretKit
import SecureEnclaveSecretKit
import SmartCardSecretKit
import SSHProtocolKit

// MARK: - Store Provider

/// Initializes and vends the SecretStoreList with all available stores.
@MainActor
final class StoreProvider {
    let storeList: SecretStoreList
    let secureEnclaveStore: SecureEnclave.Store
    let smartCardStore: SmartCard.Store

    /// Base URL of SecretAgent's sandbox container.
    /// Built directly — the old sandbox-relative replacingOccurrences approach
    /// breaks when CLI runs outside a sandbox (Bundle.main.bundleIdentifier is nil).
    nonisolated private static var agentContainerURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Containers")
            .appendingPathComponent("com.maxgoedjen.Secretive.SecretAgent")
            .appendingPathComponent("Data")
    }

    /// Path to SecretAgent's Unix domain socket.
    /// Defaults to the production socket, but can be overridden via `SECRETIVE_SOCKET_PATH`.
    nonisolated static var socketPath: String {
        if let customPath = ProcessInfo.processInfo.environment["SECRETIVE_SOCKET_PATH"], !customPath.isEmpty {
            return customPath
        }
        let debugPath = agentContainerURL.appendingPathComponent("socket-debug.ssh").path()
        if FileManager.default.fileExists(atPath: debugPath) {
            return debugPath
        }
        return agentContainerURL.appendingPathComponent("socket.ssh").path()
    }

    /// Directory where the agent writes public key `.pub` files.
    /// Defaults to the production directory, but can be overridden via `SECRETIVE_PUBLIC_KEY_DIR`.
    nonisolated static var publicKeyDirectory: URL {
        if let customDir = ProcessInfo.processInfo.environment["SECRETIVE_PUBLIC_KEY_DIR"], !customDir.isEmpty {
            return URL(fileURLWithPath: customDir)
        }
        return agentContainerURL.appendingPathComponent("PublicKeys")
    }

    // MARK: - Init

    init() {
        let seStore = SecureEnclave.Store()
        let scStore = SmartCard.Store()
        let list = SecretStoreList()
        list.add(store: seStore)
        list.add(store: scStore)
        secureEnclaveStore = seStore
        smartCardStore = scStore
        storeList = list
    }

    // MARK: - Key Lookup

    /// Resolves a user-provided `<name|fingerprint>` identifier to a unique secret.
    /// Resolution order (per spec §9):
    ///   1. Exact name match (case-sensitive)
    ///   2. Prefix name match (unique)
    ///   3. SHA256 fingerprint match
    ///   4. MD5 fingerprint match
    ///   5. Ambiguous → error
    func resolve(identifier: String) throws -> AnySecret {
        let writer = OpenSSHPublicKeyWriter()
        let all = storeList.allSecrets

        // 1. Exact name
        let exactName = all.filter { $0.name == identifier }
        if exactName.count == 1 {
            return exactName[0]
        }
        if exactName.count > 1 {
            throw CLIError.ambiguousKey(identifier, candidates: exactName.map(\.name))
        }

        // 2. Prefix name
        let prefix = all.filter { $0.name.hasPrefix(identifier) }
        if prefix.count == 1 {
            return prefix[0]
        }
        if prefix.count > 1 {
            throw CLIError.ambiguousKey(identifier, candidates: prefix.map(\.name))
        }

        // 3. SHA256 fingerprint
        let sha256 = identifier.hasPrefix("SHA256:") ? identifier : "SHA256:\(identifier)"
        let bySHA256 = all.filter { writer.openSSHSHA256Fingerprint(secret: $0) == sha256 }
        if bySHA256.count == 1 {
            return bySHA256[0]
        }

        // 4. MD5 fingerprint
        let byMD5 = all.filter {
            let fp = writer.openSSHMD5Fingerprint(secret: $0)
            return fp == identifier || fp.replacingOccurrences(of: ":", with: "") == identifier.replacingOccurrences(of: ":", with: "")
        }
        if byMD5.count == 1 {
            return byMD5[0]
        }

        throw CLIError.keyNotFound(identifier)
    }

    /// Returns all secrets, optionally filtered by store name.
    func secrets(filterStore storeName: String?) -> [(secret: AnySecret, storeName: String)] {
        storeList.stores.flatMap { store -> [(AnySecret, String)] in
            if let filter = storeName, store.name.lowercased() != filter.lowercased() {
                return []
            }
            return store.secrets.map { ($0, store.name) }
        }
    }
}
