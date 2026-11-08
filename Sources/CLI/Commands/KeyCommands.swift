import CryptoKit
import Foundation
import SecretKit
import SecureEnclaveSecretKit
import SSHProtocolKit

public typealias KeyListItem = SSHProtocolKit.KeyListItem

// MARK: - Key Commands

/// Handles all `secretive key <verb>` subcommands.
enum KeyCommands {
    static func dispatch(_ args: [String]) async {
        let pos = CommandRouter.positional(args: args)
        let wantsHelp = CommandRouter.flag("--help", in: args) || CommandRouter.flag("-h", in: args)

        guard let verb = pos.first else {
            printKeyUsage()
            exit(wantsHelp ? ExitCode.ok.rawValue : ExitCode.usage.rawValue)
        }

        if wantsHelp {
            switch verb {
            case "list": printKeyListUsage()
            case "show": printKeyShowUsage()
            case "create": printKeyCreateUsage()
            case "delete": printKeyDeleteUsage()
            case "rename": printKeyRenameUsage()
            default: printKeyUsage()
            }
            exit(ExitCode.ok.rawValue)
        }
        let rest = CommandRouter.removeFirst(verb, from: args)
        switch verb {
        case "list":
            await listKeys(rest)
        case "show":
            await showKey(rest)
        case "create":
            await createKey(rest)
        case "delete":
            await deleteKey(rest)
        case "rename":
            await renameKey(rest)
        case "--help", "-h":
            printKeyUsage()
            exit(ExitCode.ok.rawValue)
        default:
            exitWithStringError("unknown key verb '\(verb)'", code: .usage)
        }
    }

    // MARK: - key list

    @MainActor
    static func listKeys(_ args: [String]) async {
        let filterStore = CommandRouter.value(for: "--store", in: args)
        let jsonMode = CommandRouter.flag("--json", in: args)
        let socketPath = StoreProvider.socketPath

        if FileManager.default.fileExists(atPath: socketPath) {
            do {
                let items = try SafePosixSocket.listKeys(socketPath: socketPath)
                let filtered = items.filter { item in
                    guard let filter = filterStore else { return true }
                    return item.store.lowercased() == filter.lowercased()
                }
                if filtered.isEmpty {
                    printError("No keys found.")
                    return
                }
                if jsonMode {
                    JSONWriter.print(filtered)
                } else {
                    let rows = filtered.map { item in
                        [
                            item.store,
                            item.name,
                            item.algorithm,
                            item.authentication,
                            item.fingerprint_sha256,
                        ]
                    }
                    TableWriter.print(
                        columns: [
                            .init("STORE", minWidth: 14),
                            .init("NAME", minWidth: 10),
                            .init("ALGORITHM", minWidth: 9),
                            .init("AUTH", minWidth: 8),
                            .init("FINGERPRINT"),
                        ],
                        rows: rows,
                    )
                }
                return
            } catch {
                // If listKeys extension is not supported, fall through to dev socket identity reading or direct store
            }
        }

        let provider = StoreProvider()
        let pairs = provider.secrets(filterStore: filterStore)

        // Dev-mode fallback: unsigned CLI cannot read Keychain directly.
        // If Keychain returned nothing but the agent socket is live, read
        // identities via SSH agent protocol + match to .pub files on disk.
        if pairs.isEmpty {
            if FileManager.default.fileExists(atPath: socketPath), listKeysViaSocket(
                socketPath: socketPath,
                pubKeyDir: StoreProvider.publicKeyDirectory,
                jsonMode: jsonMode,
            ) {
                return
            }
            printError("No keys found.")
            if !FileManager.default.fileExists(atPath: socketPath) {
                printError("(SecretAgent not running — launch Secretive.app first)")
            } else {
                printError("(Hint: unsigned binary — Keychain access requires code signing)")
            }
            return
        }

        let writer = OpenSSHPublicKeyWriter()

        if jsonMode {
            let items = pairs.map { secret, storeName -> KeyListItem in
                KeyListItem(
                    store: storeName,
                    name: secret.name,
                    algorithm: formatAlgorithm(secret.keyType),
                    authentication: secret.authenticationRequirement.rawValue,
                    fingerprint_sha256: writer.openSSHSHA256Fingerprint(secret: secret),
                    fingerprint_md5: writer.openSSHMD5Fingerprint(secret: secret),
                    public_key: writer.openSSHString(secret: secret),
                    public_key_path: URL.publicKeyPath(for: secret, in: provider.publicKeyDirectory),
                )
            }
            JSONWriter.print(items)
        } else {
            let rows = pairs.map { secret, storeName -> [String] in
                [
                    storeName,
                    secret.name,
                    formatAlgorithm(secret.keyType),
                    formatAuth(secret.authenticationRequirement),
                    writer.openSSHSHA256Fingerprint(secret: secret),
                ]
            }
            TableWriter.print(
                columns: [
                    .init("STORE", minWidth: 14),
                    .init("NAME", minWidth: 10),
                    .init("ALGORITHM", minWidth: 9),
                    .init("AUTH", minWidth: 8),
                    .init("FINGERPRINT"),
                ],
                rows: rows,
            )
        }
    }

    // MARK: - Socket-based key listing (dev / unsigned mode)

    /// Reads identities from the SSH agent socket.
    /// Returns true if at least one key was shown.
    @discardableResult
    private static func listKeysViaSocket(socketPath: String, pubKeyDir: URL, jsonMode: Bool) -> Bool {
        guard let identities = try? SafePosixSocket.requestIdentities(socketPath: socketPath),
              !identities.isEmpty else { return false }

        // Load .pub files for name lookup (filename without extension = hex MD5)
        var pubFileContents: [(content: String, url: URL)] = []
        if let files = try? FileManager.default.contentsOfDirectory(
            at: pubKeyDir, includingPropertiesForKeys: nil,
        ) {
            for f in files where f.pathExtension == "pub" {
                if let text = try? String(contentsOf: f, encoding: .utf8) {
                    pubFileContents.append((content: text.trimmingCharacters(in: .whitespacesAndNewlines), url: f))
                }
            }
        }

        fputs("(dev mode — reading from agent socket)\n", stderr)

        struct Row {
            let algo: String
            let name: String
            let fingerprint: String
            let pubKey: String
            let pubKeyPath: String
        }

        let rows: [Row] = identities.map { identity in
            let algo = blobAlgorithm(identity.blob)
            let fp = sha256Fingerprint(identity.blob)
            let b64 = identity.blob.base64EncodedString()
            let pubKeyStr = "\(algo) \(b64)"

            // Match name: find .pub file whose content starts with same algo + blob
            let matchedPub = pubFileContents.first { $0.content.hasPrefix("\(algo) \(b64)") }
            let name = matchedPub.map { $0.url.deletingPathExtension().lastPathComponent }
                ?? (identity.comment.isEmpty ? fp : identity.comment)
            let path = matchedPub?.url.path() ?? ""

            return Row(algo: algo, name: name, fingerprint: fp, pubKey: pubKeyStr, pubKeyPath: path)
        }

        if jsonMode {
            let items = rows.map {
                KeyListItem(
                    store: "Secure Enclave",
                    name: $0.name,
                    algorithm: $0.algo,
                    authentication: "—",
                    fingerprint_sha256: $0.fingerprint,
                    fingerprint_md5: "",
                    public_key: $0.pubKey,
                    public_key_path: $0.pubKeyPath,
                )
            }
            JSONWriter.print(items)
        } else {
            let tableRows = rows.map { [$0.name, $0.algo, "—", $0.fingerprint] }
            TableWriter.print(
                columns: [
                    .init("NAME", minWidth: 10),
                    .init("ALGORITHM", minWidth: 30),
                    .init("AUTH", minWidth: 8),
                    .init("FINGERPRINT"),
                ],
                rows: tableRows,
            )
        }
        return true
    }

    // MARK: - SSH Agent Protocol Helpers

    /// Extracts the algorithm name from an SSH public key blob.
    private static func blobAlgorithm(_ blob: Data) -> String {
        guard blob.count >= 4 else { return "unknown" }
        let nameLen = Int(UInt32(bigEndian: blob[0...3].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard blob.count >= 4 + nameLen else { return "unknown" }
        return String(data: blob[4..<(4 + nameLen)], encoding: .utf8) ?? "unknown"
    }

    /// Computes SHA256 fingerprint of an SSH public key blob (OpenSSH format).
    private static func sha256Fingerprint(_ blob: Data) -> String {
        let digest = SHA256.hash(data: blob)
        let b64 = Data(digest).base64EncodedString()
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return "SHA256:\(b64)"
    }

    // MARK: - key show

    @MainActor
    static func showKey(_ args: [String]) async {
        let positional = CommandRouter.positional(args: args)
        guard let identifier = positional.first else {
            exitWithStringError("'key show' requires a <name|fingerprint> argument", code: .usage)
        }

        let publicKeyOnly = CommandRouter.flag("--public-key", in: args)
        let fingerprintOnly = CommandRouter.flag("--fingerprint", in: args)
        let pathOnly = CommandRouter.flag("--path", in: args)
        let jsonMode = CommandRouter.flag("--json", in: args)
        let outPath = CommandRouter.value(for: "--output", in: args) ?? CommandRouter.value(for: "-o", in: args)

        let socketPath = StoreProvider.socketPath
        if FileManager.default.fileExists(atPath: socketPath),
           let all = try? SafePosixSocket.listKeys(socketPath: socketPath) {
            let matched: KeyListItem
            let exact = all.filter { $0.name == identifier }
            if exact.count == 1 {
                matched = exact[0]
            } else if exact.count > 1 {
                exitWithError(.ambiguousKey(identifier, candidates: exact.map(\.name)))
            } else {
                let prefix = all.filter { $0.name.hasPrefix(identifier) }
                if prefix.count == 1 {
                    matched = prefix[0]
                } else if prefix.count > 1 {
                    exitWithError(.ambiguousKey(identifier, candidates: prefix.map(\.name)))
                } else {
                    let sha256 = identifier.hasPrefix("SHA256:") ? identifier : "SHA256:\(identifier)"
                    let bySha = all.filter { $0.fingerprint_sha256 == sha256 }
                    if bySha.count == 1 {
                        matched = bySha[0]
                    } else {
                        let idClean = identifier.replacingOccurrences(of: ":", with: "")
                        let byMd5 = all.filter {
                            $0.fingerprint_md5 == identifier || $0.fingerprint_md5.replacingOccurrences(of: ":", with: "") == idClean
                        }
                        if byMd5.count == 1 {
                            matched = byMd5[0]
                        } else {
                            exitWithError(.keyNotFound(identifier))
                        }
                    }
                }
            }
            let options = ShowOptions(
                outPath: outPath,
                publicKeyOnly: publicKeyOnly,
                fingerprintOnly: fingerprintOnly,
                pathOnly: pathOnly,
                jsonMode: jsonMode,
            )
            renderShow(item: matched, options: options)
            return
        }

        let provider = StoreProvider()
        let secret: AnySecret
        do {
            secret = try provider.resolve(identifier: identifier)
        } catch let e as CLIError {
            exitWithError(e)
        } catch {
            exitWithError(.ioError(String(describing: error)))
        }

        let writer = OpenSSHPublicKeyWriter()
        let pubKeyPath = URL.publicKeyPath(for: secret, in: provider.publicKeyDirectory)
        let sha256 = writer.openSSHSHA256Fingerprint(secret: secret)
        let md5 = writer.openSSHMD5Fingerprint(secret: secret)
        let pubKey = writer.openSSHString(secret: secret)
        let storeName = provider.storeList.stores
            .first { $0.secrets.contains(where: { $0.id == secret.id }) }?.name ?? "Unknown"

        let item = KeyListItem(
            store: storeName,
            name: secret.name,
            algorithm: formatAlgorithm(secret.keyType),
            authentication: secret.authenticationRequirement.rawValue,
            fingerprint_sha256: sha256,
            fingerprint_md5: md5,
            public_key: pubKey,
            public_key_path: pubKeyPath,
        )
        let options = ShowOptions(
            outPath: outPath,
            publicKeyOnly: publicKeyOnly,
            fingerprintOnly: fingerprintOnly,
            pathOnly: pathOnly,
            jsonMode: jsonMode,
        )
        renderShow(item: item, options: options)
    }

    private struct ShowOptions {
        let outPath: String?
        let publicKeyOnly: Bool
        let fingerprintOnly: Bool
        let pathOnly: Bool
        let jsonMode: Bool
    }

    private static func renderShow(
        item: KeyListItem,
        options: ShowOptions,
    ) {
        if options.publicKeyOnly || options.outPath != nil {
            if let path = options.outPath {
                let expanded = (path as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded)
                do {
                    try item.public_key.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    exitWithStringError("Failed to write to \(url.path): \(error.localizedDescription)", code: .cantCreate)
                }
            }
            if options.jsonMode {
                var json: [String: String] = ["public_key": item.public_key]
                if let p = options.outPath {
                    json["saved_to"] = p
                }
                JSONWriter.print(json)
            } else if let p = options.outPath {
                printError("Public key saved to: \(p)")
            } else {
                print(item.public_key)
            }
            return
        }
        if options.fingerprintOnly {
            print(item.fingerprint_sha256)
            return
        }
        if options.pathOnly {
            print(item.public_key_path)
            return
        }

        if options.jsonMode {
            JSONWriter.print(item)
            return
        }

        print("""
        \(ANSI.bold)Name\(ANSI.reset)          \(item.name)
        \(ANSI.bold)Store\(ANSI.reset)         \(item.store)
        \(ANSI.bold)Algorithm\(ANSI.reset)     \(item.algorithm)
        \(ANSI.bold)Auth\(ANSI.reset)          \(item.authentication)
        \(ANSI.bold)Fingerprint\(ANSI.reset)   \(item.fingerprint_sha256)
        \(ANSI.bold)MD5\(ANSI.reset)           \(item.fingerprint_md5)
        \(ANSI.bold)Public Key\(ANSI.reset)
        \(item.public_key)
        \(ANSI.bold)Path\(ANSI.reset)          \(item.public_key_path)
        """)
    }

    // MARK: - key create

    @MainActor
    static func createKey(_ args: [String]) async {
        let positional = CommandRouter.positional(args: args)
        guard let name = positional.first else {
            exitWithStringError("'key create' requires a <name> argument", code: .usage)
        }

        let typeStr = CommandRouter.value(for: "--type", in: args) ?? "ecdsa-256"
        let authStr = CommandRouter.value(for: "--auth", in: args) ?? "presence"
        let attribution = CommandRouter.value(for: "--attribution", in: args)
        let jsonMode = CommandRouter.flag("--json", in: args)
        let existOk = CommandRouter.flag("--exist-ok", in: args)

        let keyType: KeyType
        switch typeStr.lowercased() {
        case "ecdsa-256", "ecdsa-sha2-nistp256", "ecdsa": keyType = .ecdsa256
        case "ecdsa-384", "ecdsa-sha2-nistp384": keyType = .ecdsa384
        case "mldsa-65": keyType = .mldsa65
        case "mldsa-87": keyType = .mldsa87
        default:
            exitWithStringError(
                "unknown key type '\(typeStr)'. Valid: ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, mldsa-65, mldsa-87",
                code: .usage,
            )
        }

        let authReq: AuthenticationRequirement
        switch authStr {
        case "none": authReq = .notRequired
        case "presence": authReq = .presenceRequired
        case "biometry-current": authReq = .biometryCurrent
        default:
            exitWithStringError("unknown auth level '\(authStr)'. Valid: none, presence, biometry-current", code: .usage)
        }

        let provider = StoreProvider()

        let existing = provider.secureEnclaveStore.secrets.filter { $0.name == name }
        if !existing.isEmpty {
            if existOk {
                let existingSecret = existing[0]
                if jsonMode {
                    printKeyJson(secret: existingSecret, provider: provider)
                } else {
                    printError("✓ Key \"\(name)\" already exists")
                    print(OpenSSHPublicKeyWriter().openSSHString(secret: existingSecret))
                }
                return
            } else {
                exitWithStringError("a key named '\(name)' already exists", code: .usage)
            }
        }

        let filterStore = CommandRouter.value(for: "--store", in: args)
        if let fs = filterStore, fs.lowercased() == "smartcard" {
            exitWithStringError("SmartCard keys cannot be created programmatically (hardware limitation).", code: .usage)
        }

        let attrs = Attributes(keyType: keyType, authentication: authReq, publicKeyAttribution: attribution)

        // Option 1: IPC via SecretAgent socket (NIST AC-3 Reference Monitor)
        let socketPath = StoreProvider.socketPath
        if FileManager.default.fileExists(atPath: socketPath) {
            createKeyViaSocket(
                name: name,
                keyType: keyType,
                authReq: authReq,
                jsonMode: jsonMode,
                provider: provider,
            )
            return
        }

        // When running as a standalone CLI (outside an .app bundle), direct Keychain access
        // is forbidden by macOS security policies without restricted entitlements.
        if Bundle.main.bundleIdentifier == nil {
            exitWithStringError(
                "SecretAgent socket not found at '\(socketPath)'. Please ensure SecretAgent is running.",
                code: .unavailable,
            )
        }

        // Fallback: Direct Keychain store write (Option 2: Embedded in Secretive.app)
        do {
            let secret = try await provider.secureEnclaveStore.create(name: name, attributes: attrs)
            Notifications.postSecretStoreUpdated()

            if jsonMode {
                printKeyJson(secret: secret, provider: provider)
            } else {
                printError("✓ Created key \"\(name)\" (\(typeStr), \(authStr) required)")
                print(OpenSSHPublicKeyWriter().openSSHString(secret: secret))
            }
        } catch {
            exitWithStringError("failed to create key: \(error.localizedDescription)", code: .usage)
        }
    }

    private static func createKeyViaSocket(
        name: String,
        keyType: KeyType,
        authReq: AuthenticationRequirement,
        jsonMode: Bool,
        provider: StoreProvider,
    ) {
        let typeStr = formatAlgorithm(keyType)
        do {
            let (algo, blob) = try SafePosixSocket.createKey(
                socketPath: StoreProvider.socketPath,
                name: name,
                keyType: typeStr,
                requireBiometrics: authReq != .notRequired,
            )
            Notifications.postSecretStoreUpdated()

            let b64 = blob.base64EncodedString()
            let pubKeyStr = "\(algo) \(b64) \(name)"
            let sha256 = sha256Fingerprint(blob)
            let md5 = Insecure.MD5.hash(data: blob).formatted(.hex(separator: ":"))
            let minimalHex = md5.replacingOccurrences(of: ":", with: "")
            let pubKeyPath = provider.publicKeyDirectory.appendingPathComponent("\(minimalHex).pub").path()

            if jsonMode {
                struct SocketKeyItem: Encodable {
                    let store, name, algorithm, authentication, fingerprint_sha256, fingerprint_md5, public_key, public_key_path: String
                }
                JSONWriter.print(SocketKeyItem(
                    store: "Secure Enclave",
                    name: name,
                    algorithm: formatAlgorithm(keyType),
                    authentication: authReq.rawValue,
                    fingerprint_sha256: sha256,
                    fingerprint_md5: md5,
                    public_key: pubKeyStr,
                    public_key_path: pubKeyPath,
                ))
            } else {
                printError("✓ Created key \"\(name)\" (\(typeStr), \(authReq.rawValue) required)")
                print(pubKeyStr)
            }
        } catch let error as SafePosixSocketError {
            exitWithStringError("SecretAgent key creation failed: \(error.localizedDescription)", code: .software)
        } catch {
            exitWithStringError("failed to create key: \(error.localizedDescription)", code: .software)
        }
    }

    // MARK: - key delete

    @MainActor
    static func deleteKey(_ args: [String]) async {
        let positional = CommandRouter.positional(args: args)
        guard let identifier = positional.first else {
            exitWithStringError("'key delete' requires a <name|fingerprint> argument", code: .usage)
        }
        let force = CommandRouter.flag("--force", in: args)

        let socketPath = StoreProvider.socketPath
        if FileManager.default.fileExists(atPath: socketPath) {
            if !force {
                guard isStdinTTY else {
                    exitWithStringError(
                        "Non-interactive terminal detected. Pass --force to confirm deletion.",
                        code: .usage,
                    )
                }
                printError("⚠ This will permanently destroy the key \"\(identifier)\".")
                printError("  Secure Enclave keys CANNOT be recovered or exported.\n")
                fputs("Type the key name to confirm: ", stderr)
                guard let input = readLine(), input == identifier else {
                    exitWithStringError("confirmation failed. Key not deleted.", code: .usage)
                }
            }

            do {
                try SafePosixSocket.deleteKey(socketPath: socketPath, identifier: identifier)
                Notifications.postSecretStoreUpdated()
                printError("✓ Deleted key \"\(identifier)\"")
                return
            } catch _ as SafePosixSocketError {
                // If socket extension failed, fall back to direct deletion
            } catch {
                // Fall back
            }
        }

        let provider = StoreProvider()
        do {
            let secret = try provider.resolve(identifier: identifier)
            guard let seSecret = secret.base as? SecureEnclaveSecretKit.SecureEnclave.Secret else {
                exitWithStringError("only Secure Enclave keys can be deleted.", code: .usage)
            }

            if !force {
                guard isStdinTTY else { exitWithStringError(
                    "Non-interactive terminal detected. Pass --force to confirm deletion.",
                    code: .usage,
                ) }
                printError("⚠ This will permanently destroy the key \"\(secret.name)\" (\(formatAlgorithm(secret.keyType))).")
                printError("  Secure Enclave keys CANNOT be recovered or exported.\n")
                fputs("Type the key name to confirm: ", stderr)
                guard let input = readLine(), input == secret.name else {
                    exitWithStringError("confirmation failed. Key not deleted.", code: .usage)
                }
            }

            try await provider.secureEnclaveStore.delete(secret: seSecret)
            Notifications.postSecretStoreUpdated()
            printError("✓ Deleted key \"\(secret.name)\"")
        } catch let e as CLIError {
            exitWithError(e)
        } catch {
            exitWithError(.ioError(String(describing: error)))
        }
    }

    // MARK: - key rename

    @MainActor
    static func renameKey(_ args: [String]) async {
        let positional = CommandRouter.positional(args: args)
        guard let identifier = positional.first else {
            exitWithStringError("'key rename' requires a <name|fingerprint> argument", code: .usage)
        }
        guard let newName = CommandRouter.value(for: "--name", in: args) else {
            exitWithStringError("'key rename' requires a --name <new-name> argument", code: .usage)
        }
        let attribution = CommandRouter.value(for: "--attribution", in: args)

        let socketPath = StoreProvider.socketPath
        if FileManager.default.fileExists(atPath: socketPath) {
            do {
                try SafePosixSocket.renameKey(socketPath: socketPath, identifier: identifier, newName: newName, attribution: attribution)
                Notifications.postSecretStoreUpdated()
                printError("✓ Renamed key to \"\(newName)\"")
                return
            } catch let error as SafePosixSocketError {
                exitWithStringError("SecretAgent key rename failed: \(error.localizedDescription)", code: .software)
            } catch {
                exitWithStringError("failed to rename key: \(error.localizedDescription)", code: .software)
            }
        }

        let provider = StoreProvider()
        do {
            let secret = try provider.resolve(identifier: identifier)
            guard let seSecret = secret.base as? SecureEnclaveSecretKit.SecureEnclave.Secret else {
                exitWithStringError("only Secure Enclave keys can be renamed.", code: .usage)
            }

            let newAttrs = Attributes(
                keyType: secret.keyType,
                authentication: secret.authenticationRequirement,
                publicKeyAttribution: attribution ?? secret.attributes.publicKeyAttribution,
            )

            try await provider.secureEnclaveStore.update(secret: seSecret, name: newName, attributes: newAttrs)
            Notifications.postSecretStoreUpdated()
            printError("✓ Renamed key to \"\(newName)\"")
        } catch let e as CLIError {
            exitWithError(e)
        } catch {
            exitWithError(.ioError(String(describing: error)))
        }
    }

    private static func printKeyJson(secret: any Secret, provider: StoreProvider) {
        let writer = OpenSSHPublicKeyWriter()
        let storeName = "Secure Enclave"
        JSONWriter.print(KeyListItem(
            store: storeName, name: secret.name,
            algorithm: formatAlgorithm(secret.keyType),
            authentication: secret.authenticationRequirement.rawValue,
            fingerprint_sha256: writer.openSSHSHA256Fingerprint(secret: secret),
            fingerprint_md5: writer.openSSHMD5Fingerprint(secret: secret),
            public_key: writer.openSSHString(secret: secret),
            public_key_path: URL.publicKeyPath(for: secret, in: provider.publicKeyDirectory),
        ))
    }

    // MARK: - Helpers

    static func formatAlgorithm(_ keyType: KeyType) -> String {
        switch keyType {
        case .ecdsa256: "ecdsa-sha2-nistp256"
        case .ecdsa384: "ecdsa-sha2-nistp384"
        case .mldsa65: "mldsa-65"
        case .mldsa87: "mldsa-87"
        case .rsa2048: "rsa-2048"
        default: keyType.description
        }
    }

    static func formatAuth(_ auth: AuthenticationRequirement) -> String {
        switch auth {
        case .notRequired: "none"
        case .presenceRequired: "presence"
        case .biometryCurrent: "biometry-current"
        case .unknown: "unknown"
        }
    }

    static func printKeyUsage() {
        let usage = """
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Manage Secure Enclave Keys

        \(ANSI.bold)USAGE\(ANSI.reset)

          secretive key <command> [options]

        \(ANSI.bold)COMMANDS\(ANSI.reset)

          list                 List all available keys
          show                 Show details, public key, or fingerprint for a specific key
          create               Create a new hardware-backed key in the Secure Enclave
          delete               Permanently destroy a key
          rename               Rename an existing key

        Run `secretive key <command> --help` for specific options and examples.
        """
        print(usage)
    }

    static func printKeyCreateUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Create a new hardware-backed key

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive key create <name> [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          --type <algo>        The cryptographic algorithm to use for the new key.
                               [choices: "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "mldsa-65", "mldsa-87"] 
                               [default: "ecdsa-sha2-nistp256"]
                               
          --auth <level>       The biometric authentication requirement (Touch ID / Apple Watch).
                               [choices: "none", "presence", "biometry-current"] [default: "presence"]
                               
          -o, --output <file>  Save the generated public key to a file path.
          --attribution <str>  Set a custom public key attribution string.
          --exist-ok           Do not return an error if a key with this name already exists.

        \(ANSI.bold)GLOBAL OPTIONS\(ANSI.reset)
          -h, --help           Output usage information
          --json               Format output as machine-readable JSON
        """)
    }

    static func printKeyShowUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Show details for a specific key

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive key show <name|fingerprint> [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          --public-key         Output only the OpenSSH public key string.
          --fingerprint        Output only the SHA256 fingerprint.
          --path               Output only the path to the public key file on disk.
          -o, --output <file>  Export the public key to a file path.
        """)
    }

    static func printKeyListUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — List all available keys

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive key list [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          --store <name>       Filter keys by a specific Secure Enclave store.
        """)
    }

    static func printKeyDeleteUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Permanently destroy a key

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive key delete <name|fingerprint> [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          --force              Skip the interactive confirmation prompt.
        """)
    }

    static func printKeyRenameUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Rename an existing key

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive key rename <name|fingerprint> --name <new-name> [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          --name <new-name>    The new name for the key. [REQUIRED]
          --attribution <str>  Update the custom public key attribution string.
        """)
    }
}

// MARK: - URL Helper

extension URL {
    static func publicKeyPath(for secret: some Secret, in directory: URL) -> String {
        let writer = OpenSSHPublicKeyWriter()
        let minimalHex = writer.openSSHMD5Fingerprint(secret: secret).replacingOccurrences(of: ":", with: "")
        return directory.appendingPathComponent("\(minimalHex).pub").path
    }
}

// MARK: - StoreProvider extension

extension StoreProvider {
    var publicKeyDirectory: URL {
        StoreProvider.publicKeyDirectory
    }
}
