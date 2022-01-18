import Foundation
import Combine

/// A concrete implementation of ``UpdaterProtocol`` which considers the current release and OS version.
public actor Updater: ObservableObject, UpdaterProtocol {

    @MainActor @Published public var update: Release?
    public let testBuild: Bool

    /// The current OS version.
    private let osVersion: SemVer
    /// The current version of the app that is running.
    private let currentVersion: SemVer
    /// The timer responsible for checking for updates regularly.
    private var timer: Timer? = nil

    /// Initializes an Updater.
    /// - Parameters:
    ///   - osVersion: The current OS version.
    ///   - currentVersion: The current version of the app that is running.
    public init(osVersion: SemVer = SemVer(ProcessInfo.processInfo.operatingSystemVersion), currentVersion: SemVer = SemVer(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")) {
        self.osVersion = osVersion
        self.currentVersion = currentVersion
        testBuild = currentVersion == SemVer("0.0.0")
    }

    /// Begins checking for updates with the specified frequency.
    /// - Parameter checkFrequency: The interval at which the Updater should check for updates. Subject to a tolerance of 1 hour.
    public func beginChecking(checkFrequency: TimeInterval = Measurement(value: 24, unit: UnitDuration.hours).converted(to: .seconds).value) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: checkFrequency, repeats: true) { _ in
            Task {
                await self.checkForUpdates()
            }
        }
        timer?.tolerance = 60*60
    }

    /// Ends checking for updates.
    public func stopChecking() {
        timer?.invalidate()
        timer = nil
    }

    /// Manually trigger an update check.
    public func checkForUpdates() async {
        guard let (data, _) = try? await URLSession.shared.data(from: Constants.updateURL),
              let releases = try? JSONDecoder().decode([Release].self, from: data) else { return }
        await evaluate(releases: releases)
    }

    /// Ignores a specified release. `update` will be nil if the user has ignored the latest available release.
    /// - Parameter release: The release to ignore.
    public func ignore(release: Release) async {
        guard !release.critical else { return }
        defaults.set(true, forKey: release.name)
        await setUpdate(update: update)
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
            await setUpdate(update: update)
        }
    }

    @MainActor private func setUpdate(update: Release?) {
        self.update = update
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

extension Updater {

    enum Constants {
        static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases")!
    }

}

@available(macOS, deprecated: 12)
 extension URLSession {

     // Backport for macOS 11
     func data(from url: URL) async throws -> (Data, URLResponse) {
         try await withCheckedThrowingContinuation { continuation in
             URLSession.shared.dataTask(with: url) { data, response, error in
                 guard let data = data, let response = response else {
                     continuation.resume(throwing: error ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil))
                     return
                 }
                 continuation.resume(returning: (data, response))
             }
         }
     }

 }
