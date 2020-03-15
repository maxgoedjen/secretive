import Foundation
import Combine

class PreviewUpdater: UpdaterProtocol {

    let update: Release?

    init(update: Update = .none) {
        switch update {
        case .none:
            self.update = nil
        case .advisory:
            self.update = Release(name: "10.10.10", html_url: URL(string: "https://example.com")!, body: "Some regular update")
        case .critical:
            self.update = Release(name: "10.10.10", html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        }
    }

}

extension PreviewUpdater {

    enum Update {
        case none, advisory, critical
    }

}
