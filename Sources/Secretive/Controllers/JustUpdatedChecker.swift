import Foundation
import Combine
import AppKit

protocol JustUpdatedCheckerProtocol: ObservableObject {
    var justUpdated: Bool { get }
}

class JustUpdatedChecker: ObservableObject, JustUpdatedCheckerProtocol {

    @Published var justUpdated: Bool = false

    init() {
        check()
    }

    func check() {
        let lastBuild = SettingsStore.get(key: Constants.previousVersionUserDefaultsKey) ?? "None"
        let currentBuild = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        SettingsStore.set(key: Constants.previousVersionUserDefaultsKey, value: currentBuild)
        justUpdated = lastBuild != currentBuild
    }
}

extension JustUpdatedChecker {

    enum Constants {
        static let previousVersionUserDefaultsKey = "com.maxgoedjen.Secretive.lastBuild"
    }

}
