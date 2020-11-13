import Foundation
import Combine

public protocol UpdaterProtocol: ObservableObject {

    var update: Release? { get }
    func ignore(release: Release)
    
}

public class Updater: ObservableObject, UpdaterProtocol {

    @Published public var update: Release?

    public init() {
        checkForUpdates()
        let timer = Timer.scheduledTimer(withTimeInterval: 60*60*24, repeats: true) { _ in
            self.checkForUpdates()
        }
        timer.tolerance = 60*60
    }

    public func checkForUpdates() {
        URLSession.shared.dataTask(with: Constants.updateURL) { data, _, _ in
            guard let data = data else { return }
            guard let release = try? JSONDecoder().decode(Release.self, from: data) else { return }
            self.evaluate(release: release)
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

    func evaluate(release: Release) {
        guard !userIgnored(release: release) else { return }
        let latestVersion = SemVer(release.name)
        let currentVersion = SemVer(Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
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

struct SemVer {

    let versionNumbers: [Int]

    init(_ version: String) {
        // Betas have the format 1.2.3_beta1
        let strippedBeta = version.split(separator: "_").first!
        var split = strippedBeta.split(separator: ".").compactMap { Int($0) }
        while split.count < 3 {
            split.append(0)
        }
        versionNumbers = split
    }

}

extension SemVer: Comparable {

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
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
        static let updateURL = URL(string: "https://api.github.com/repos/maxgoedjen/secretive/releases/latest")!
    }

}

public struct Release: Codable {

    public let name: String
    public let html_url: URL
    public let body: String

    public init(name: String, html_url: URL, body: String) {
        self.name = name
        self.html_url = html_url
        self.body = body
    }

}

extension Release: Identifiable {

    public var id: String {
        html_url.absoluteString
    }

}

extension Release {

    public var critical: Bool {
        body.contains(Constants.securityContent)
    }

}

extension Release {

    enum Constants {
        static let securityContent = "Critical Security Update"
    }

}
