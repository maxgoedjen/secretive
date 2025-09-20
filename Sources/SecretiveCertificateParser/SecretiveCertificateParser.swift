import Foundation
import OSLog
import XPCWrappers
import SSHProtocolKit

final class SecretiveCertificateParser: NSObject, XPCProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.SecretiveCertificateParser", category: "SecretiveCertificateParser")

    func process(_ data: Data) async throws -> OpenSSHCertificate {
        let parser = OpenSSHCertificateParser()
        let result = try parser.parse(data: data)
        logger.log("Parser parsed certificate \(result.debugDescription)")
        return result
    }

}
