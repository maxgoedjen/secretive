import Foundation
import Combine

protocol UpdaterProtocol: ObservableObject {
    var update: Release? { get }
}

class Updater: ObservableObject, UpdaterProtocol {

    @Published var update: Release?

    init() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            self.checkForUpdates()
        }
    }

    func checkForUpdates() {
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
        static let updateURL = URL(string: "https://api.github.com/repos/rails/rails/releases/latest")!
    }

}


struct Release: Codable {
    let name: String
    let html_url: URL
    fileprivate let body: String
}


extension Release {

    var critical: Bool {
        return body.contains(Constants.securityContent)
    }

}

extension Release {

    enum Constants {
        static let securityContent = "Critical Security Update"
    }

}
