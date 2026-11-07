import CertificateKit
import Foundation
import SSHProtocolKit

public typealias CertListItem = SSHProtocolKit.CertListItem

// MARK: - Cert Commands

/// Handles all `secretive cert <verb>` subcommands.
enum CertCommands {
    static func dispatch(_ args: [String]) async {
        let pos = CommandRouter.positional(args: args)
        let wantsHelp = CommandRouter.flag("--help", in: args) || CommandRouter.flag("-h", in: args)

        guard let verb = pos.first else {
            printCertUsage()
            exit(wantsHelp ? ExitCode.ok.rawValue : ExitCode.usage.rawValue)
        }

        if wantsHelp {
            switch verb {
            case "list": printCertListUsage()
            case "import": printCertImportUsage()
            case "delete": printCertDeleteUsage()
            default: printCertUsage()
            }
            exit(ExitCode.ok.rawValue)
        }
        let rest = CommandRouter.removeFirst(verb, from: args)
        switch verb {
        case "list":
            await listCerts(rest)
        case "import":
            await importCert(rest)
        case "delete":
            await deleteCert(rest)
        case "--help", "-h":
            printCertUsage()
            exit(ExitCode.ok.rawValue)
        default:
            exitWithStringError("unknown cert verb '\(verb)'", code: .usage)
        }
    }

    // MARK: - cert list

    @MainActor
    static func listCerts(_ args: [String]) async {
        let jsonMode = CommandRouter.flag("--json", in: args)
        let socketPath = StoreProvider.socketPath

        if FileManager.default.fileExists(atPath: socketPath) {
            do {
                let items = try SafePosixSocket.listCerts(socketPath: socketPath)
                if jsonMode {
                    JSONWriter.print(items)
                } else {
                    if items.isEmpty {
                        printError("No certificates found.")
                        return
                    }
                    let rows: [[String]] = items.map {
                        [$0.name, $0.key_id, String($0.serial), $0.principals.joined(separator: ","), $0.valid_until ?? "forever"]
                    }
                    TableWriter.print(
                        columns: [
                            .init("NAME", minWidth: 10),
                            .init("KEY ID", minWidth: 14),
                            .init("SERIAL", minWidth: 6),
                            .init("PRINCIPALS", minWidth: 12),
                            .init("VALID UNTIL"),
                        ],
                        rows: rows,
                    )
                }
                return
            } catch {
                // Fall back to direct store if socket query failed
            }
        }

        let certStore = CertificateStore()
        let certs = certStore.certificates

        if jsonMode {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let items = certs.map { cert in
                let validUntil = cert.openSSHCertificate.validityRange.map { dateFormatter.string(from: $0.upperBound) }
                return CertListItem(
                    name: cert.openSSHCertificate.name,
                    key_id: cert.openSSHCertificate.keyID,
                    serial: cert.openSSHCertificate.serial,
                    principals: cert.openSSHCertificate.principals,
                    valid_until: validUntil,
                )
            }
            JSONWriter.print(items)
        } else {
            if certs.isEmpty {
                printError("No certificates found.")
                if !FileManager.default.fileExists(atPath: socketPath) {
                    printError("(SecretAgent not running — launch Secretive.app first)")
                }
                return
            }
            let rows: [[String]] = certs.map { cert in
                let name = cert.openSSHCertificate.name
                let keyID = cert.openSSHCertificate.keyID
                let serial = String(cert.openSSHCertificate.serial)
                let principals = cert.openSSHCertificate.principals.joined(separator: ",")
                let validUntil: String
                if let range = cert.openSSHCertificate.validityRange {
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyy-MM-dd"
                    validUntil = fmt.string(from: range.upperBound)
                } else {
                    validUntil = "forever"
                }
                return [name, keyID, serial, principals, validUntil]
            }
            TableWriter.print(
                columns: [
                    .init("NAME", minWidth: 10),
                    .init("KEY ID", minWidth: 14),
                    .init("SERIAL", minWidth: 6),
                    .init("PRINCIPALS", minWidth: 12),
                    .init("VALID UNTIL"),
                ],
                rows: rows,
            )
        }
    }

    // MARK: - cert import

    @MainActor
    static func importCert(_ args: [String]) async {
        let positional = CommandRouter.positional(args: args)
        guard let path = positional.first else {
            exitWithStringError("'cert import' requires a <path> argument", code: .usage)
        }
        let overrideName = CommandRouter.value(for: "--name", in: args)

        let fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            exitWithStringError("could not read file at '\(path)': \(error.localizedDescription)", code: .usage)
        }

        let socketPath = StoreProvider.socketPath
        if FileManager.default.fileExists(atPath: socketPath) {
            do {
                let importedName = try SafePosixSocket.importCert(
                    socketPath: socketPath,
                    data: data,
                    nameOverride: overrideName,
                )
                Notifications.postCertificateStoreUpdated()
                printError("✓ Imported certificate \"\(importedName)\"")
                return
            } catch let error as SafePosixSocketError {
                exitWithStringError("SecretAgent certificate import failed: \(error.localizedDescription)", code: .software)
            } catch {
                exitWithStringError("failed to import certificate: \(error.localizedDescription)", code: .software)
            }
        }

        let parser = OpenSSHCertificateParser()
        let openSSHCert: OpenSSHCertificate
        do {
            openSSHCert = try parser.parse(data: data)
        } catch {
            exitWithStringError("failed to parse certificate", code: .usage)
        }

        var cert = Certificate(openSSHCertificate: openSSHCert, rawData: data)
        if let newName = overrideName {
            cert.openSSHCertificate.name = newName
        }

        let store = CertificateStore()
        do {
            try store.save(certificate: cert)
            Notifications.postCertificateStoreUpdated()
            printError("✓ Imported certificate \"\(cert.openSSHCertificate.name)\"")
        } catch let e as CLIError {
            exitWithError(e)
        } catch {
            exitWithStringError("failed to save certificate: \(error.localizedDescription)", code: .usage)
        }
    }

    // MARK: - cert delete

    @MainActor
    static func deleteCert(_ args: [String]) async {
        let positional = CommandRouter.positional(args: args)
        guard let identifier = positional.first else {
            exitWithStringError("'cert delete' requires a <name|key-id> argument", code: .usage)
        }
        let force = CommandRouter.flag("--force", in: args)

        if !force {
            guard isStdinTTY
            else { exitWithStringError("Non-interactive terminal detected. Pass --force to confirm deletion.", code: .usage) }
            printError(
                "⚠ This will permanently delete the certificate \"\(identifier)\".",
            )
            fputs("Type the certificate name to confirm: ", stderr)
            guard let input = readLine(), input == identifier else {
                exitWithStringError("confirmation failed. Certificate not deleted.", code: .usage)
            }
        }

        let socketPath = StoreProvider.socketPath
        if FileManager.default.fileExists(atPath: socketPath) {
            do {
                try SafePosixSocket.deleteCert(socketPath: socketPath, identifier: identifier)
                Notifications.postCertificateStoreUpdated()
                printError("✓ Deleted certificate \"\(identifier)\"")
                return
            } catch let error as SafePosixSocketError {
                exitWithStringError("SecretAgent certificate deletion failed: \(error.localizedDescription)", code: .software)
            } catch {
                exitWithStringError("failed to delete certificate: \(error.localizedDescription)", code: .software)
            }
        }

        let store = CertificateStore()
        let certs = store.certificates
        let exactName = certs.filter { $0.openSSHCertificate.name == identifier }
        let exactID = certs.filter { $0.openSSHCertificate.keyID == identifier }

        let target: Certificate
        if exactName.count == 1 {
            target = exactName[0]
        } else if exactID.count == 1 {
            target = exactID[0]
        } else {
            exitWithStringError("could not find exactly one certificate matching '\(identifier)'", code: .usage)
        }

        do {
            try store.delete(certificate: target)
            Notifications.postCertificateStoreUpdated()
            printError("✓ Deleted certificate \"\(target.openSSHCertificate.name)\"")
        } catch let e as CLIError {
            exitWithError(e)
        } catch {
            exitWithStringError("failed to delete certificate: \(error.localizedDescription)", code: .usage)
        }
    }

    static func printCertUsage() {
        let usage = """
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Manage OpenSSH Certificates

        \(ANSI.bold)USAGE\(ANSI.reset)

          secretive cert <command> [options]

        \(ANSI.bold)COMMANDS\(ANSI.reset)

          list                 List imported certificates
          import               Import a certificate from a file
          delete               Delete an imported certificate

        Run `secretive cert <command> --help` for specific options and examples.
        """
        print(usage)
    }

    static func printCertListUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — List imported certificates

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive cert list [options]

        \(ANSI.bold)GLOBAL OPTIONS\(ANSI.reset)
          -h, --help           Output usage information
          --json               Format output as machine-readable JSON
        """)
    }

    static func printCertImportUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Import a certificate from a file

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive cert import <path> [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          <path>               Path to the .pub certificate file to import. [REQUIRED]
          --name <override>    Override the certificate name instead of using the filename.

        \(ANSI.bold)GLOBAL OPTIONS\(ANSI.reset)
          -h, --help           Output usage information
          --json               Format output as machine-readable JSON
        """)
    }

    static func printCertDeleteUsage() {
        print("""
        \(ANSI.bold)Secretive CLI\(ANSI.reset) — Delete an imported certificate

        \(ANSI.bold)USAGE\(ANSI.reset)
          secretive cert delete <name|key-id> [options]

        \(ANSI.bold)OPTIONS\(ANSI.reset)
          --force              Skip the interactive confirmation prompt.

        \(ANSI.bold)GLOBAL OPTIONS\(ANSI.reset)
          -h, --help           Output usage information
          --json               Format output as machine-readable JSON
        """)
    }
}
