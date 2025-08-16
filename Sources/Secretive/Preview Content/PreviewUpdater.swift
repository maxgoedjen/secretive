import Foundation
import Observation
import Brief

@Observable @MainActor final class PreviewUpdater: UpdaterProtocol {

    var update: Release? = nil

    let testBuild = false

    init(update: Update = .none) {
        switch update {
        case .none:
            self.update = nil
        case .advisory:
            self.update = Release(name: "10.10.10", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Some regular update")
        case .critical:
            self.update = Release(name: "10.10.10", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        }
    }

    func ignore(release: Release) async {
    }
    
}

extension PreviewUpdater {

    enum Update {
        case none, advisory, critical
    }

}
