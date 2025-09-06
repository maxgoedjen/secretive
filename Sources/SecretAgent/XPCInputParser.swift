import Foundation
import SecretAgentKit

struct XPCAgentInputParser: SSHAgentInputParserProtocol {

    func parse(data: Data) async throws -> SSHAgent.Request {
        fatalError()
    }

}
