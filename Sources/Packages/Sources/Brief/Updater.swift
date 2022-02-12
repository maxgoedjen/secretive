import Foundation
import Combine

/// A concrete implementation of ``UpdateCheckerProtocol`` which considers the current release and OS version.
public class UpdateChecker: ObservableObject, UpdateCheckerProtocol {

    @Published public var update: Release?
    public let testBuild: Bool

    /// The current OS version.
    private let osVersion: SemVer
    /// The current version of the app that is running.
    private let currentVersion: SemVer

    /// Initializes an Updater.
    /// - Parameters:
    ///   - checkOnLaunch: A boolean describing whether the Updater should check for available updates on launch.
    ///   - checkFrequency: The interval at which the Updater should check for updates. Subject to a tolerance of 1 hour.
    ///   - osVersion: The current OS version.
    ///   - currentVersion: The current version of the app that is running.
    public init(checkOnLaunch: Bool, checkFrequency: TimeInterval = Measurement(value: 24, unit: UnitDuration.hours).converted(to: .seconds).value, osVersion: SemVer = SemVer(ProcessInfo.processInfo.operatingSystemVersion), currentVersion: SemVer = SemVer(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")) {
        self.osVersion = osVersion
        self.currentVersion = currentVersion
        testBuild = currentVersion == SemVer("0.0.0")
        if checkOnLaunch {
            // Don't do a launch check if the user hasn't seen the setup prompt explaining updater yet.
            checkForUpdates()
        }
        let timer = Timer.scheduledTimer(withTimeInterval: checkFrequency, repeats: true) { _ in
            self.checkForUpdates()
        }
        timer.tolerance = 60*60
    }

    /// Manually trigger an update check.
    public func checkForUpdates() {
        URLSession.shared.dataTask(with: Constants.updateURL) { data, _, _ in
            guard let data = data else { return }
            guard let releases = try? JSONDecoder().decode([Release].self, from: data) else { return }
            self.evaluate(releases: releases)
        }.resume()
    }

    /// Ignores a specified release. `update` will be nil if the user has ignored the latest available release.
    /// - Parameter release: The release to ignore.
    public func ignore(release: Release) {
        guard !release.critical else { return }
        defaults.set(true, forKey: release.name)
        DispatchQueue.main.async {
            self.update = nil
        }
    }

}

extension UpdateChecker {

    /// Evaluates the available downloadable releases, and selects the newest non-prerelease release that the user is able to run.
    /// - Parameter releases: An array of ``Release`` objects.
    func evaluate(releases: [Release]) {
        guard let release = releases
                .sorted()
                .reversed()
                .filter({ !$0.prerelease })
                .first(where: { $0.minimumOSVersion <= osVersion }) else { return }
        guard !userIgnored(release: release) else { return }
        guard !release.prerelease else { return }
        let latestVersion = SemVer(release.name)
        if latestVersion > currentVersion {
            DispatchQueue.main.async {
                self.update = release
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

extension UpdateChecker {

    enum Constants {
        static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases")!
    }

}
