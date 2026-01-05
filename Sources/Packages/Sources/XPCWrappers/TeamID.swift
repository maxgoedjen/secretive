import Foundation

extension ProcessInfo {
    private static let fallbackTeamID = "Z72PRUAWF6"

    private static let teamID: String = {
        #if DEBUG
        guard let task = SecTaskCreateFromSelf(nil) else {
            assertionFailure("SecTaskCreateFromSelf failed")
            return fallbackTeamID
        }

        guard let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.team-identifier" as CFString, nil) as? String else {
            assertionFailure("SecTaskCopyValueForEntitlement(com.apple.developer.team-identifier) failed")
            return fallbackTeamID
        }

        return value
        #else
        /// Always use hardcoded team ID for release builds, just in case.
        return fallbackTeamID
        #endif
    }()

    public var teamID: String { Self.teamID }
}
