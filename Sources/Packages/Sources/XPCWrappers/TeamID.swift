import Foundation

extension ProcessInfo {
    private static let teamID: String = {
        TeamIDResolver.resolve(
            entitlementTeamID: TeamIDResolver.currentEntitlementTeamID(),
            configuredFallbackTeamID: TeamIDResolver.configuredFallbackTeamID(in: Bundle.main.infoDictionary)
        )
    }()

    public var teamID: String { Self.teamID }
}

enum TeamIDResolver {
    static let infoDictionaryKey = "SecretiveDevelopmentTeam"

    static func currentEntitlementTeamID() -> String? {
        guard let task = SecTaskCreateFromSelf(nil) else {
            assertionFailure("SecTaskCreateFromSelf failed")
            return nil
        }

        guard let entitlementTeamID = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.team-identifier" as CFString,
            nil
        ) as? String else {
            assertionFailure("SecTaskCopyValueForEntitlement(com.apple.developer.team-identifier) failed")
            return nil
        }

        return normalizedTeamID(entitlementTeamID)
    }

    static func configuredFallbackTeamID(in infoDictionary: [String: Any]?) -> String? {
        guard let configuredFallbackTeamID = infoDictionary?[infoDictionaryKey] as? String else {
            return nil
        }

        return normalizedTeamID(configuredFallbackTeamID)
    }

    static func resolve(entitlementTeamID: String?, configuredFallbackTeamID: String?) -> String {
        if let entitlementTeamID = normalizedTeamID(entitlementTeamID) {
            return entitlementTeamID
        }

        if let configuredFallbackTeamID {
            return configuredFallbackTeamID
        }

        preconditionFailure("Expected either an entitlement team ID or a configured fallback team ID.")
    }

    private static func normalizedTeamID(_ teamID: String?) -> String? {
        guard let teamID else {
            return nil
        }

        let trimmedTeamID = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTeamID.isEmpty else {
            return nil
        }

        return trimmedTeamID
    }
}
