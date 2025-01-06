import Foundation
import Synchronization
import Observation
import Brief

@Observable class PreviewUpdater: UpdaterProtocol {

    var update: Release? {
        _update.withLock { $0 }
    }
    let _update: Mutex<Release?> = .init(nil)

    let testBuild = false

    init(update: Update = .none) {
        switch update {
        case .none:
            _update.withLock {
                $0 = nil
            }
        case .advisory:
            _update.withLock {
                $0 = Release(name: "10.10.10", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Some regular update")
            }
        case .critical:
            _update.withLock {
                $0 = Release(name: "10.10.10", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")

            }
        }
    }

}

extension PreviewUpdater {

    enum Update {
        case none, advisory, critical
    }

}
