import Foundation
import Brief

final class ReleasesDownloader: NSObject, ReleasesDownloaderProtocol {

    @objc func downloadReleases(with reply: @escaping (Data?, (any Error)?) -> Void) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: Constants.updateURL)
                let releases = try JSONDecoder().decode([Release].self, from: data)
                print(releases)
                let jsonOut = try JSONEncoder().encode(releases)
                reply(jsonOut, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
}

extension ReleasesDownloader {

    enum Constants {
        static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases")!
    }

}
