import Foundation
import os
import Observation
import Brief

@Observable final class PreviewUpdater: UpdaterProtocol {

    var update: Release? {
        _update.lockedValue
    }
    let _update: OSAllocatedUnfairLock<Release?> = .init(uncheckedState: nil)

    let testBuild = false

    init(update: Update = .none) {
        switch update {
        case .none:
            _update.lockedValue = nil
        case .advisory:
            _update.lockedValue = Release(name: "10.10.10", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Some regular update")
        case .critical:
            _update.lockedValue = Release(name: "10.10.10", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
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
