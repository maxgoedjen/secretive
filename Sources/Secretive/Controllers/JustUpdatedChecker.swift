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
        let lastBuild = UserDefaults.standard.object(forKey: Constants.previousVersionUserDefaultsKey) as? String ?? "None"
        let currentBuild = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        UserDefaults.standard.set(currentBuild, forKey: Constants.previousVersionUserDefaultsKey)
        justUpdated = lastBuild != currentBuild
    }



}

extension JustUpdatedChecker {

    enum Constants {
        static let previousVersionUserDefaultsKey = BundlePrefix + ".lastBuild"
    }

}
