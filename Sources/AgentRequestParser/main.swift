import XPC
import SecretAgentKit
import OSLog

private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent.AgentRequestParser", category: "Parser")

func handleRequest(_ request: XPCListener.IncomingSessionRequest) -> XPCListener.IncomingSessionRequest.Decision {
    logger.log("Parser received inbound request")
    return request.accept { xpcMessage in
        xpcMessage.handoffReply(to: .global(qos: .userInteractive)) {
            logger.log("Parser accepted inbound request")
            handle(with: xpcMessage)
        }
    }
}

func handle(with xpcMessage: XPCReceivedMessage) {
    do {
        let parser = SSHAgentInputParser()
        let result = try parser.parse(data: xpcMessage.wrappedDecode())
        logger.log("Parser parsed message as type \(result.debugDescription)")
        xpcMessage.reply(result)
    } catch {
        logger.error("Parser failed with error \(error)")
        xpcMessage.reply(error)
    }
}

extension XPCReceivedMessage {

    func wrappedDecode() throws(SSHAgentInputParser.AgentParsingError) -> Data {
        do {
            return try decode(as: Data.self)
        } catch {
            throw SSHAgentInputParser.AgentParsingError.invalidData
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
