import Foundation
import OSLog
import XPCWrappers
import Brief

final class SecretiveUpdater: NSObject, XPCProtocol {

    private let logger = Logger(subsystem: "com.maxgoedjen.secretive.ReleasesDownloader", category: "ReleasesDownloader")

    enum Constants {
        static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases")!
    }

    func process(_: Data) async throws -> [Release] {
        let (data, _) = try await URLSession.shared.data(from: Constants.updateURL)
        return try JSONDecoder().decode([Release].self, from: data)
    }

}
