import Foundation

@objc public protocol ReleasesDownloaderProtocol {

    func downloadReleases(with reply: @escaping (Data?, (any Error)?) -> Void)

}

extension ReleasesDownloaderProtocol {

    func downloadReleases() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            downloadReleases { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NoDataError())
                }
            }
        }
    }

}

struct NoDataError: Error {}
