import XPC
import SecretAgentKit
import OSLog

private let logger = Logger(subsystem: "com.maxgoedjen.secretive.secretagent.AgentRequestParser", category: "Parser")

func handleRequest(_ request: XPCListener.IncomingSessionRequest) -> XPCListener.IncomingSessionRequest.Decision {
    logger.log("Parser received inbound request")
    return request.accept { xpcDictionary in
        xpcDictionary.handoffReply(to: .global(qos: .userInteractive)) {
            logger.log("Parser accepted inbound request")
            do {
                let parser = SSHAgentInputParser()
                let result = try parser.parse(data: xpcDictionary.decode(as: Data.self))
                logger.log("Parser parsed message as type \(result.debugDescription)")
                xpcDictionary.reply(result)
            } catch let error as SSHAgentInputParser.AgentParsingError {
                logger.error("Parser failed with error \(error)")
                xpcDictionary.reply(error)
            } catch {
                // This should never actually happen because SSHAgentInputParser is a typed thrower, but the type system doesn't seem to know that across framework boundaries?
                logger.error("Parser failed with unknown error \(error)")
            }
        }
    }
}

public struct WrappedError<Wrapped: Codable & Error>: Codable {

    public struct DescriptionOnlyError: Error, Codable {
        let localizedDescription: String
    }

    public let wrapped: Wrapped

    public init(_ error: Wrapped) {
       wrapped = error
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
