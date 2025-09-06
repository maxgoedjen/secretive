import XPC
import SecretAgentKit

func handleRequest(_ request: XPCListener.IncomingSessionRequest) -> XPCListener.IncomingSessionRequest.Decision {
    request.accept { message in
        return try? SSHAgentInputParser().parse(data: message)
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
    dispatchMain()
} catch {
    print("Failed to create listener, error: \(error)")
}
