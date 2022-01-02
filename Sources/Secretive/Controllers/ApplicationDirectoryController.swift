import Foundation

struct ApplicationDirectoryController {
}

extension ApplicationDirectoryController {

    var isInApplicationsDirectory: Bool {
        let bundlePath = Bundle.main.bundlePath
        for directory in NSSearchPathForDirectoriesInDomains(.allApplicationsDirectory, .allDomainsMask, true) {
            if bundlePath.hasPrefix(directory) {
                return true
            }
        }
        if bundlePath.contains("/Library/Developer/Xcode") {
            return true
        }
        return false
    }

}
