import XPC
import OSLog
import Brief

private let logger = Logger(subsystem: "com.maxgoedjen.secretive.ReleasesDownloader", category: "ReleasesDownloader")

enum Constants {
    static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases")!
}

func handleRequest(_ request: XPCListener.IncomingSessionRequest) -> XPCListener.IncomingSessionRequest.Decision {
    logger.log("ReleasesDownloader received inbound request")
    return request.accept { xpcDictionary in
        xpcDictionary.handoffReply(to: .global(qos: .userInteractive)) {
            logger.log("ReleasesDownloader accepted inbound request")
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: Constants.updateURL)
                    let releases = try JSONDecoder().decode([Release].self, from: data)
                    xpcDictionary.reply(releases)
                } catch {
                    logger.error("ReleasesDownloader failed with unknown error \(error)")
                    xpcDictionary.reply([] as [Release])
                }
            }
        }
    }
}

do {
    if #available(macOS 26.0, *) {
        _ = try XPCListener(
            service: "com.maxgoedjen.Secretive.ReleasesDownloader",
            requirement: .isFromSameTeam(),
            incomingSessionHandler: handleRequest(_:)
        )
    } else {
        _ = try XPCListener(service: "com.maxgoedjen.Secretive.ReleasesDownloader", incomingSessionHandler: handleRequest(_:))
    }
    logger.log("ReleasesDownloader initialized")
    dispatchMain()
} catch {
    logger.error("Failed to create ReleasesDownloader, error: \(error)")
}
