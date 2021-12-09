import Foundation
import Combine

public protocol UpdaterProtocol: ObservableObject {

    var update: Release? { get }

}

public class Updater: ObservableObject, UpdaterProtocol {

    @Published public var update: Release?

    private let osVersion: SemVer
    private let currentVersion: SemVer

    public init(checkOnLaunch: Bool, osVersion: SemVer = SemVer(ProcessInfo.processInfo.operatingSystemVersion), currentVersion: SemVer = SemVer(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")) {
        self.osVersion = osVersion
        self.currentVersion = currentVersion
        if checkOnLaunch {
            // Don't do a launch check if the user hasn't seen the setup prompt explaining updater yet.
            checkForUpdates()
        }
        let timer = Timer.scheduledTimer(withTimeInterval: 60*60*24, repeats: true) { _ in
            self.checkForUpdates()
        }
        timer.tolerance = 60*60
    }

    public func checkForUpdates() {
        URLSession.shared.dataTask(with: Constants.updateURL) { data, _, _ in
            guard let data = data else { return }
            guard let releases = try? JSONDecoder().decode([Release].self, from: data) else { return }
            self.evaluate(releases: releases)
        }.resume()
    }

    public func ignore(release: Release) {
        guard !release.critical else { return }
        defaults.set(true, forKey: release.name)
        DispatchQueue.main.async {
            self.update = nil
        }
    }

}

extension Updater {

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

    func userIgnored(release: Release) -> Bool {
        guard !release.critical else { return false }
        return defaults.bool(forKey: release.name)
    }

    var defaults: UserDefaults {
        UserDefaults(suiteName: "com.maxgoedjen.Secretive.updater.ignorelist")!
    }
}

public struct SemVer {

    let versionNumbers: [Int]

    public init(_ version: String) {
        // Betas have the format 1.2.3_beta1
        let strippedBeta = version.split(separator: "_").first!
        var split = strippedBeta.split(separator: ".").compactMap { Int($0) }
        while split.count < 3 {
            split.append(0)
        }
        versionNumbers = split
    }

    public init(_ version: OperatingSystemVersion) {
        versionNumbers = [version.majorVersion, version.minorVersion, version.patchVersion]
    }

}

extension SemVer: Comparable {

    public static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        for (latest, current) in zip(lhs.versionNumbers, rhs.versionNumbers) {
            if latest < current {
                return true
            } else if latest > current {
                return false
            }
        }
        return false
    }


}

extension Updater {

    enum Constants {
        static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases")!
    }

}

public struct Release: Codable {

    public let name: String
    public let prerelease: Bool
    public let html_url: URL
    public let body: String

    public init(name: String, prerelease: Bool, html_url: URL, body: String) {
        self.name = name
        self.prerelease = prerelease
        self.html_url = html_url
        self.body = body
    }

}

extension Release: Identifiable {

    public var id: String {
        html_url.absoluteString
    }

}

extension Release: Comparable {

    public static func < (lhs: Release, rhs: Release) -> Bool {
        lhs.version < rhs.version
    }

}

extension Release {

    public var critical: Bool {
        body.contains(Constants.securityContent)
    }

    public var version: SemVer {
        SemVer(name)
    }

    public var minimumOSVersion: SemVer {
        guard let range = body.range(of: "Minimum macOS Version"),
              let numberStart = body.rangeOfCharacter(from: CharacterSet.decimalDigits, options: [], range: range.upperBound..<body.endIndex) else { return SemVer("11.0.0") }
        let numbersEnd = body.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines, options: [], range: numberStart.upperBound..<body.endIndex)?.lowerBound ?? body.endIndex
        let version = numberStart.lowerBound..<numbersEnd
        return SemVer(String(body[version]))
    }

}

extension Release {

    enum Constants {
        static let securityContent = "Critical Security Update"
    }

}
