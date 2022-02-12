import Foundation
import Brief
import AppleArchive
import System
import Cocoa
import Security.Authorization
import Security.AuthorizationTags

class Updater: UpdaterProtocol {

    func installUpdate(url: URL) async throws -> String {
        try await authorize()
//        let (downloadedURL, _) = try await URLSession.shared.download(from: url)
//        let unzipped = try await decompress(url: downloadedURL)
//        let config = NSWorkspace.OpenConfiguration()
//        config.activates = true
//
        return "OK"
    }

    func decompress(url: URL) async throws -> URL {
        let zipURL = url.deletingPathExtension().appendingPathExtension("zip")
        try FileManager.default.copyItem(at: url, to: zipURL)
        let id = UUID()
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(id.uuidString)/")
        _ = try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: [:])
        let process = Process()
        let pipe = Pipe()
        process.launchPath = "/usr/bin/unzip"
        process.arguments = ["-o", zipURL.path, "-d", destinationURL.path]
        process.standardOutput = pipe
        try process.run()
        _ = try pipe.fileHandleForReading.readToEnd()
        guard let appURL = try FileManager.default.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "app" }) else {
            throw DecompressionError(reason: "Unzip failed")
        }
        return appURL
    }

    func move(url: URL) async throws {
        try await authorize()
        try await move(url: url)
        try await revokeAuthorization()
    }

    func authorize() async throws {
        let flags = AuthorizationFlags()
        var authorization: AuthorizationRef? = nil
        let status = AuthorizationCreate(nil, nil, flags, &authorization)
        print(status)
        print("Hello")
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        kAuthorizationRightExecute.withCString { cString in
            var item = AuthorizationItem(name: cString, valueLength: 0, value: nil, flags: 0)
            withUnsafeMutablePointer(to: &item) { pointer in
                var rights = AuthorizationRights(count: 1, items: pointer)
                let out = AuthorizationCopyRights(authorization!, &rights, nil, authFlags, nil)
                print(out)
            }
        }
    }

    func revokeAuthorization() async throws {

    }

    func priveledgedMove(url: URL) async throws {

    }

}

extension Updater {
    struct DecompressionError: Error, LocalizedError {
        let reason: String
    }
}

extension URLSession {

    @available(macOS, deprecated: 12.0)
    public func download(from url: URL) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = downloadTask(with: url) { url, response, error in
                guard let url = url, let response = response else {
                    continuation.resume(throwing: error ?? UnknownError())
                    return
                }
                continuation.resume(returning: (url, response))
            }
            task.resume()
        }
    }

    struct UnknownError: Error {}

}
