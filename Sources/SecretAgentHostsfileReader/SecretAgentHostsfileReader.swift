import Foundation
import OSLog
import XPCWrappers
import SSHProtocolKit

final class SecretAgentHostsfileReader: NSObject, XPCProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.SecretAgentHostsfileReader", category: "SecretAgentHostsfileReader")

    func process(_ data: Data) async throws -> [Data: String] {
        logger.log("Parser parsed certificate")
        var result: [Data: String] = [:]
        // FIXME: THIS
        for try await line in URL(filePath: "/Users/max/.ssh/known_hosts").lines {
            let split = line.split(separator: " ").map(String.init)
            guard split.count == 3 else { continue }
            guard let decoded = Data(base64Encoded: split[2]) else { continue }
            let reader = OpenSSHReader(data: decoded)
            _ = try reader.readNextChunk()
            let key = try reader.readNextChunk()
            result[key] = split[0]
        }
        return result
    }

}
