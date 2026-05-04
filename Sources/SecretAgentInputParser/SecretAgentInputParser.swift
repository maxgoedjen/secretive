import Foundation
import OSLog
import XPCWrappers
import SecretAgentKit
import SSHProtocolKit

final class SecretAgentInputParser: NSObject, XPCProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.SecretAgentInputParser", category: "SecretAgentInputParser")

    func process(_ data: Data) async throws -> SSHAgent.Request {
        let parser = SSHAgentInputParser()
        let result = try parser.parse(data: data)
        logger.log("Parser parsed message as type \(result.debugDescription)")
        return result
    }

}
