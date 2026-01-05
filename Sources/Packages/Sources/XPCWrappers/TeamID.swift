import Foundation

extension ProcessInfo {
    private static let fallbackTeamID = "Z72PRUAWF6"

    private static let teamID: String = {
        guard let task = SecTaskCreateFromSelf(nil) else {
            assertionFailure("SecTaskCreateFromSelf failed")
            return fallbackTeamID
        }

        guard let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.team-identifier" as CFString, nil) as? String else {
            assertionFailure("SecTaskCopyValueForEntitlement(com.apple.developer.team-identifier) failed")
            return fallbackTeamID
        }

        return value
    }()

    public var teamID: String { Self.teamID }
}
