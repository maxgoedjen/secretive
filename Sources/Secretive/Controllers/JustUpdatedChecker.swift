import Foundation
import AppKit

@MainActor protocol JustUpdatedCheckerProtocol: Observable {
    var justUpdatedBuild: Bool { get }
    var justUpdatedOS: Bool { get }
}

@Observable @MainActor class JustUpdatedChecker: JustUpdatedCheckerProtocol {

    var justUpdatedBuild: Bool = false
    var justUpdatedOS: Bool = false

    nonisolated init() {
        Task { @MainActor in
            check()
        }
    }

    private func check() {
        let lastBuild = UserDefaults.standard.object(forKey: Constants.previousVersionUserDefaultsKey) as? String
        let lastOS = UserDefaults.standard.object(forKey: Constants.previousOSVersionUserDefaultsKey) as? String
        let currentBuild = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let osRaw = ProcessInfo.processInfo.operatingSystemVersion
        let currentOS = "\(osRaw.majorVersion).\(osRaw.minorVersion).\(osRaw.patchVersion)"
        UserDefaults.standard.set(currentBuild, forKey: Constants.previousVersionUserDefaultsKey)
        UserDefaults.standard.set(currentOS, forKey: Constants.previousOSVersionUserDefaultsKey)
        justUpdatedBuild = lastBuild != currentBuild
        // To prevent this showing on first lauch for every user, only show if lastBuild is non-nil.
        justUpdatedOS = lastBuild != nil && lastOS != currentOS
    }



}

extension JustUpdatedChecker {

    enum Constants {
        static let previousVersionUserDefaultsKey = "com.cursorinternal.Secretive.lastBuild"
        static let previousOSVersionUserDefaultsKey = "com.cursorinternal.Secretive.lastOS"
    }

}
