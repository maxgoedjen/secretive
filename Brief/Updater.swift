import Foundation
import Combine

public protocol UpdaterProtocol: ObservableObject {

    var update: Release? { get }

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

    func evaluate(release: Release) {
        let latestVersion = semVer(from: release.name)
        let currentVersion = semVer(from: Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String)
        for (latest, current) in zip(latestVersion, currentVersion) {
            if latest > current {
                DispatchQueue.main.async {
                    self.update = release
                }
                return
            }
        }
    }

    func semVer(from stringVersion: String) -> [Int] {
        var split = stringVersion.split(separator: ".").compactMap { Int($0) }
        while split.count < 3 {
            split.append(0)
        }
        return split
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


extension Release {

    public var critical: Bool {
        return body.contains(Constants.securityContent)
    }

}

extension Release {

    enum Constants {
        static let securityContent = "Critical Security Update"
    }

}
