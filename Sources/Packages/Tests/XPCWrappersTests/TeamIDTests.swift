import Testing
@testable import XPCWrappers

@Suite struct TeamIDTests {

    @Test func resolvePrefersEntitlementTeamIDOverConfiguredFallback() {
        #expect(
            TeamIDResolver.resolve(
                entitlementTeamID: "ACTUALTEAM",
                configuredFallbackTeamID: "CONFIGTEAM"
            ) == "ACTUALTEAM"
        )
    }

    @Test func resolveFallsBackToConfiguredTeamIDWhenEntitlementIsMissing() {
        #expect(
            TeamIDResolver.resolve(
                entitlementTeamID: nil,
                configuredFallbackTeamID: "CONFIGTEAM"
            ) == "CONFIGTEAM"
        )
    }

    @Test func configuredFallbackTeamIDReadsInfoDictionaryValue() {
        #expect(
            TeamIDResolver.configuredFallbackTeamID(
                in: [TeamIDResolver.infoDictionaryKey: "CONFIGTEAM"]
            ) == "CONFIGTEAM"
        )
    }

}
