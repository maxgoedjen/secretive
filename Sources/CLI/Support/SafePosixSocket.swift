import Darwin
import Foundation
import SSHProtocolKit

// MARK: - Safe POSIX Socket Error

enum SafePosixSocketError: LocalizedError {
    case pathTooLong(limit: Int, actual: Int)
    case socketCreationFailed(errno: Int32)
    case connectionFailed(errno: Int32)
    case sendFailed(errno: Int32)
    case receiveFailed(errno: Int32)
    case connectionClosedPrematurely
    case invalidPacketLength(Int)
    case extensionFailed
    case unexpectedResponse(UInt8)

    var errorDescription: String? {
        switch self {
        case let .pathTooLong(limit, actual):
            "Socket path is too long (\(actual) bytes > \(limit) bytes limit)"
        case let .socketCreationFailed(err):
            "Failed to create socket: \(String(cString: strerror(err)))"
        case let .connectionFailed(err):
            "Failed to connect to SecretAgent socket: \(String(cString: strerror(err)))"
        case let .sendFailed(err):
            "Failed to write to socket: \(String(cString: strerror(err)))"
        case let .receiveFailed(err):
            "Failed to read from socket: \(String(cString: strerror(err)))"
        case .connectionClosedPrematurely:
            "Connection closed prematurely by SecretAgent"
        case let .invalidPacketLength(len):
            "Invalid agent packet length: \(len)"
        case .extensionFailed:
            "SecretAgent rejected key operation"
        case let .unexpectedResponse(code):
            "Unexpected agent response code: \(code)"
        }
    }
}

// MARK: - Safe POSIX Socket

/// A hardened POSIX domain socket client designed for zero-trust local IPC.
/// Conforms to NIST SP 800-53 r5 (AC-3, SI-11) and CIS Apple macOS Benchmark:
/// - Enforces Darwin sun_len and sun_path bounds (< 104 bytes)
/// - Sets SO_NOSIGPIPE to eliminate SIGPIPE crashes
/// - Handles EINTR and partial reads/writes in bounded loops
nonisolated final class SafePosixSocket: Sendable {
    private let fileDescriptor: Int32

    nonisolated init(socketPath: String) throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path) // 104 on Darwin
        guard pathBytes.count <= maxLen else {
            throw SafePosixSocketError.pathTooLong(limit: maxLen - 1, actual: pathBytes.count - 1)
        }
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size - maxLen + pathBytes.count)
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            pathBytes.withUnsafeBufferPointer { src in
                guard let base = src.baseAddress else { return }
                UnsafeMutableRawPointer(ptr).copyMemory(from: base, byteCount: src.count)
            }
        }

        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw SafePosixSocketError.socketCreationFailed(errno: errno)
        }

        var nosigpipe: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(sock, saPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connectResult == 0 else {
            let err = errno
            close(sock)
            throw SafePosixSocketError.connectionFailed(errno: err)
        }

        fileDescriptor = sock
    }

    nonisolated deinit {
        close(fileDescriptor)
    }

    nonisolated func sendExact(_ data: Data) throws {
        var totalSent = 0
        let count = data.count
        while totalSent < count {
            let sent = data.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return -1 }
                return Darwin.send(fileDescriptor, base.advanced(by: totalSent), count - totalSent, 0)
            }
            if sent > 0 {
                totalSent += sent
            } else if sent < 0 {
                if errno == EINTR {
                    continue
                }
                throw SafePosixSocketError.sendFailed(errno: errno)
            } else {
                throw SafePosixSocketError.connectionClosedPrematurely
            }
        }
    }

    nonisolated func readExact(count: Int) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: count)
        var totalRead = 0
        while totalRead < count {
            let bytesRead = buffer.withUnsafeMutableBytes { raw -> Int in
                guard let base = raw.baseAddress else { return -1 }
                return Darwin.recv(fileDescriptor, base.advanced(by: totalRead), count - totalRead, 0)
            }
            if bytesRead > 0 {
                totalRead += bytesRead
            } else if bytesRead == 0 {
                throw SafePosixSocketError.connectionClosedPrematurely
            } else {
                if errno == EINTR {
                    continue
                }
                throw SafePosixSocketError.receiveFailed(errno: errno)
            }
        }
        return Data(buffer)
    }

    nonisolated func sendPacket(_ body: Data) throws {
        var lenBE = UInt32(body.count).bigEndian
        let header = Data(bytes: &lenBE, count: 4)
        try sendExact(header + body)
    }

    nonisolated func readPacket() throws -> Data {
        let lenData = try readExact(count: 4)
        let length = Int(UInt32(bigEndian: lenData.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard length > 0, length < 10_000_000 else {
            throw SafePosixSocketError.invalidPacketLength(length)
        }
        return try readExact(count: length)
    }
}

// MARK: - OpenSSH Extension Operations

extension SafePosixSocket {
    struct Identity: Sendable {
        let blob: Data
        let comment: String

        nonisolated init(blob: Data, comment: String) {
            self.blob = blob
            self.comment = comment
        }
    }

    /// Reads all identities via standard OpenSSH agent protocol (SSH2_AGENTC_REQUEST_IDENTITIES = 11).
    nonisolated static func requestIdentities(socketPath: String) throws -> [Identity] {
        let sock = try SafePosixSocket(socketPath: socketPath)
        try sock.sendPacket(Data([SSHAgent.Request.requestIdentities.protocolID]))
        let response = try sock.readPacket()
        guard !response.isEmpty, response[0] == SSHAgent.Response.agentIdentitiesAnswer.rawValue else {
            throw SafePosixSocketError.unexpectedResponse(response.first ?? 0)
        }
        guard response.count >= 5 else {
            return []
        }
        let numKeys = Int(UInt32(bigEndian: response[1...4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard numKeys > 0 else { return [] }

        var identities: [Identity] = []
        var offset = 5
        let body = [UInt8](response)

        for _ in 0..<numKeys {
            guard offset + 4 <= body.count else { break }
            let blobLen = Int(UInt32(bigEndian: response[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
            let blobEnd = offset + 4 + blobLen
            guard blobEnd <= body.count else { break }
            let blob = Data(body[(offset + 4)..<blobEnd])

            let commentOffset = blobEnd
            guard commentOffset + 4 <= body.count else { break }
            let commentLen =
                Int(UInt32(bigEndian: response[commentOffset..<commentOffset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
            let commentEnd = commentOffset + 4 + commentLen
            guard commentEnd <= body.count else { break }
            let commentData = Data(body[(commentOffset + 4)..<commentEnd])
            let comment = String(data: commentData, encoding: .utf8) ?? ""

            identities.append(Identity(blob: blob, comment: comment))
            offset = commentEnd
        }
        return identities
    }

    /// Creates a key on the Secure Enclave via SecretAgent IPC extension.
    /// Returns the algorithm name and the public key blob.
    nonisolated static func createKey(
        socketPath: String,
        name: String,
        keyType: String,
        requireBiometrics: Bool,
    ) throws -> (algorithm: String, publicKeyBlob: Data) {
        let sock = try SafePosixSocket(socketPath: socketPath)

        // Packet: byte 27 + string "create-key@secretive.app" + string name + string keyType + byte bool
        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("create-key@secretive.app".lengthAndData)
        body.append(name.lengthAndData)
        body.append(keyType.lengthAndData)
        var bioByte: UInt8 = requireBiometrics ? 1 : 0
        body.append(Data(bytes: &bioByte, count: 1))

        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty else {
            throw SafePosixSocketError.connectionClosedPrematurely
        }
        guard response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }

        // Response contains length-prefixed pubKeyBlob
        guard response.count >= 5 else {
            throw SafePosixSocketError.extensionFailed
        }
        let blobLen = Int(UInt32(bigEndian: response[1...4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard response.count >= 5 + blobLen else {
            throw SafePosixSocketError.extensionFailed
        }
        let pubKeyBlob = Data(response[5..<(5 + blobLen)])

        // Extract algorithm from blob
        guard pubKeyBlob.count >= 4 else {
            return ("unknown", pubKeyBlob)
        }
        let algoLen = Int(UInt32(bigEndian: pubKeyBlob[0...3].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard pubKeyBlob.count >= 4 + algoLen else {
            return ("unknown", pubKeyBlob)
        }
        let algo = String(data: pubKeyBlob[4..<(4 + algoLen)], encoding: .utf8) ?? "unknown"
        return (algo, pubKeyBlob)
    }

    /// Deletes a key on the Secure Enclave via SecretAgent IPC extension.
    nonisolated static func deleteKey(socketPath: String, identifier: String) throws {
        let sock = try SafePosixSocket(socketPath: socketPath)

        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("delete-key@secretive.app".lengthAndData)
        body.append(identifier.lengthAndData)

        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty else {
            throw SafePosixSocketError.connectionClosedPrematurely
        }
        guard response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }
    }

    /// Renames a key via SecretAgent IPC extension.
    nonisolated static func renameKey(socketPath: String, identifier: String, newName: String, attribution: String?) throws {
        let sock = try SafePosixSocket(socketPath: socketPath)
        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("rename-key@secretive.app".lengthAndData)
        body.append(identifier.lengthAndData)
        body.append(newName.lengthAndData)
        if let attr = attribution {
            body.append(attr.lengthAndData)
        }
        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty, response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }
    }

    /// Fetches all keys with full metadata via SecretAgent IPC extension.
    nonisolated static func listKeys(socketPath: String) throws -> [KeyListItem] {
        let sock = try SafePosixSocket(socketPath: socketPath)
        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("list-keys@secretive.app".lengthAndData)
        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty, response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }
        guard response.count >= 5 else { return [] }
        let dataLen = Int(UInt32(bigEndian: response[1...4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard response.count >= 5 + dataLen else {
            throw SafePosixSocketError.extensionFailed
        }
        let jsonData = Data(response[5..<(5 + dataLen)])
        return try JSONDecoder().decode([KeyListItem].self, from: jsonData)
    }

    /// Fetches all certificates via SecretAgent IPC extension.
    nonisolated static func listCerts(socketPath: String) throws -> [CertListItem] {
        let sock = try SafePosixSocket(socketPath: socketPath)
        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("list-certs@secretive.app".lengthAndData)
        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty, response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }
        guard response.count >= 5 else { return [] }
        let dataLen = Int(UInt32(bigEndian: response[1...4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard response.count >= 5 + dataLen else {
            throw SafePosixSocketError.extensionFailed
        }
        let jsonData = Data(response[5..<(5 + dataLen)])
        return try JSONDecoder().decode([CertListItem].self, from: jsonData)
    }

    /// Imports a certificate via SecretAgent IPC extension. Returns imported certificate name.
    nonisolated static func importCert(socketPath: String, data: Data, nameOverride: String?) throws -> String {
        let sock = try SafePosixSocket(socketPath: socketPath)
        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("import-cert@secretive.app".lengthAndData)
        body.append(data.lengthAndData)
        if let name = nameOverride {
            body.append(name.lengthAndData)
        }
        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty, response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }
        guard response.count >= 5 else { return "unnamed" }
        let nameLen = Int(UInt32(bigEndian: response[1...4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        guard response.count >= 5 + nameLen else { return "unnamed" }
        return String(data: response[5..<(5 + nameLen)], encoding: .utf8) ?? "unnamed"
    }

    /// Deletes a certificate via SecretAgent IPC extension.
    nonisolated static func deleteCert(socketPath: String, identifier: String) throws {
        let sock = try SafePosixSocket(socketPath: socketPath)
        var body = Data([SSHAgent.Request.protocolExtension(.empty).protocolID])
        body.append("delete-cert@secretive.app".lengthAndData)
        body.append(identifier.lengthAndData)
        try sock.sendPacket(body)
        let response = try sock.readPacket()
        guard !response.isEmpty, response[0] == SSHAgent.Response.agentSuccess.rawValue else {
            throw SafePosixSocketError.extensionFailed
        }
    }
}
