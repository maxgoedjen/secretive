import Foundation
import Brief
import AppleArchive
import System
import Cocoa
import Security.Authorization
import Security.AuthorizationTags

class Updater: UpdaterProtocol {

    func installUpdate(url: URL, to destinationURL: URL) async throws -> String {
//        let (downloadedURL, _) = try await URLSession.shared.download(from: url)
//        let unzipped = try await decompress(url: downloadedURL)
//        try await move(url: unzipped, to: destinationURL)
//        let config = NSWorkspace.OpenConfiguration()
//        config.activates = true
        // TODO: clean
        _ = try await authorize()
//        if let host = NSRunningApplication.runningApplications(withBundleIdentifier: "com.maxgoedjen.Secretive.Host").first(where: { $0.bundleURL?.path.hasPrefix("/Applications") ?? false }) {
//            host.terminate()
//
//        }
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

    func move(url: URL, to destinationURL: URL) async throws {
        let auth = try await authorize()
        try await move(url: url, to: destinationURL)
        try await revokeAuthorization(auth)
    }

    func authorize() async throws -> AuthorizationRef {
        let flags = AuthorizationFlags()
        var authorization: AuthorizationRef? = nil
        AuthorizationCreate(nil, nil, flags, &authorization)
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        var result: OSStatus?
        kAuthorizationRightExecute.withCString { cString in
            var item = AuthorizationItem(name: cString, valueLength: 0, value: nil, flags: 0)
            withUnsafeMutablePointer(to: &item) { pointer in
                var rights = AuthorizationRights(count: 1, items: pointer)
                result = AuthorizationCopyRights(authorization!, &rights, nil, authFlags, nil)
            }
        }
        guard result == errAuthorizationSuccess, let authorization = authorization else {
            throw RightsNotAcquiredError()
        }
        return authorization

    }

    func revokeAuthorization(_ authorization: AuthorizationRef) async throws {
        AuthorizationFree(authorization, .destroyRights)
    }

    func priveledgedMove(url: URL, to destination: URL) async throws {
        try FileManager.default.replaceItemAt(destination, withItemAt: url)
    }

}

extension Updater {

    struct DecompressionError: Error, LocalizedError {
        let reason: String
    }

    struct RightsNotAcquiredError: Error, LocalizedError {
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
