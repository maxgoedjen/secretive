import Foundation
import Combine
import Brief

class PreviewUpdater: UpdateCheckerProtocol {

    let update: Release?
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

}

extension PreviewUpdater {

    enum Update {
        case none, advisory, critical
    }

}
