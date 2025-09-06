import XPC
import SecretAgentKit
import OSLog

private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent.AgentRequestParser", category: "Parser")

func handleRequest(_ request: XPCListener.IncomingSessionRequest) -> XPCListener.IncomingSessionRequest.Decision {
    logger.log("Parser received inbound request")
    return request.accept { message in
        logger.log("Parser accepted inbound request")
        do {
            let result = try SSHAgentInputParser().parse(data: message)
            logger.log("Parser parsed message as type \(result.debugDescription)")
            return result
        } catch {
            logger.error("Parser failed with error \(error)")
            return nil
        }
    }
}

do {
    if #available(macOS 26.0, *) {
        _ = try XPCListener(
            service: "com.maxgoedjen.Secretive.AgentRequestParser",
            requirement: .isFromSameTeam(),
            incomingSessionHandler: handleRequest(_:)
        )
    } else {
        _ = try XPCListener(service: "com.maxgoedjen.Secretive.AgentRequestParser", incomingSessionHandler: handleRequest(_:))
    }
    logger.log("Parser initialized")
    dispatchMain()
} catch {
    logger.error("Failed to create parser, error: \(error)")
}
