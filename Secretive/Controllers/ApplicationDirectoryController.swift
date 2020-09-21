import Foundation

struct ApplicationDirectoryController {
}

extension ApplicationDirectoryController {

    var isInApplicationsDirectory: Bool {
        #if DEBUG
        return true
        #else
        let bundlePath = Bundle.main.bundlePath
        for directory in NSSearchPathForDirectoriesInDomains(.applicationDirectory, .allDomainsMask, true) {
            if bundlePath.hasPrefix(directory) {
                return true
            }
        }
        return false
        #endif
    }

}
