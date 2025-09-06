import Foundation
import Observation

/// A concrete implementation of ``UpdaterProtocol`` which considers the current release and OS version.
@Observable public final class Updater: UpdaterProtocol, Sendable {

    private let state = State()
    @MainActor @Observable public final class State {
        var update: Release? = nil
        nonisolated init() {}
    }
    public var update: Release? {
        state.update
    }

    /// The current version of the app that is running.
    public let currentVersion: SemVer

    /// The current OS version.
    private let osVersion: SemVer

    /// Initializes an Updater.
    /// - Parameters:
    ///   - checkOnLaunch: A boolean describing whether the Updater should check for available updates on launch.
    ///   - checkFrequency: The interval at which the Updater should check for updates. Subject to a tolerance of 1 hour.
    ///   - osVersion: The current OS version.
    ///   - currentVersion: The current version of the app that is running.
    public init(
        checkOnLaunch: Bool,
        checkFrequency: TimeInterval = Measurement(value: 24, unit: UnitDuration.hours).converted(to: .seconds).value,
        osVersion: SemVer = SemVer(ProcessInfo.processInfo.operatingSystemVersion),
        currentVersion: SemVer = SemVer(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
    ) {
        self.osVersion = osVersion
        self.currentVersion = currentVersion
        Task {
            if checkOnLaunch {
                try await checkForUpdates()
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Int(checkFrequency)))
                try await checkForUpdates()
            }
        }
    }

    /// Manually trigger an update check.
    public func checkForUpdates() async throws {
        let releaseData = try await withXPCCall(to: "com.maxgoedjen.Secretive.ReleasesDownloader", ReleasesDownloaderProtocol.self) {
            try await $0.downloadReleases()
        }
        let releases = try JSONDecoder().decode([Release].self, from: releaseData)
        await evaluate(releases: releases)
    }

    func withXPCCall<ServiceProtocol, Result>(to service: String, _: ServiceProtocol.Type, closure: (ServiceProtocol) async throws -> Result) async rethrows -> Result {
        let connectionToService = NSXPCConnection(serviceName: "com.maxgoedjen.Secretive.ReleasesDownloader")
        connectionToService.remoteObjectInterface = NSXPCInterface(with: (any ReleasesDownloaderProtocol).self)// fixme
        connectionToService.resume()
        let service = connectionToService.remoteObjectProxy as! ServiceProtocol
        let result = try await closure(service)
        connectionToService.invalidate()
        return result
    }

    /// Ignores a specified release. `update` will be nil if the user has ignored the latest available release.
    /// - Parameter release: The release to ignore.
    public func ignore(release: Release) async {
        guard !release.critical else { return }
        defaults.set(true, forKey: release.name)
        await MainActor.run {
            state.update = nil
        }
    }

}

extension Updater {

    /// Evaluates the available downloadable releases, and selects the newest non-prerelease release that the user is able to run.
    /// - Parameter releases: An array of ``Release`` objects.
    func evaluate(releases: [Release]) async {
        guard let release = releases
                .sorted()
                .reversed()
                .filter({ !$0.prerelease })
                .first(where: { $0.minimumOSVersion <= osVersion }) else { return }
        guard !userIgnored(release: release) else { return }
        guard !release.prerelease else { return }
        let latestVersion = SemVer(release.name)
        if latestVersion > currentVersion {
            await MainActor.run {
                state.update = release
            }
        }
    }

    /// Checks whether the user has ignored a release.
    /// - Parameter release: The release to check.
    /// - Returns: A boolean describing whether the user has ignored the release. Will always be false if the release is critical.
    func userIgnored(release: Release) -> Bool {
        guard !release.critical else { return false }
        return defaults.bool(forKey: release.name)
    }

    /// The user defaults used to store user ignore state.
    var defaults: UserDefaults {
        UserDefaults(suiteName: "com.maxgoedjen.Secretive.updater.ignorelist")!
    }

}

