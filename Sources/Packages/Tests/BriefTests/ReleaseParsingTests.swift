import Testing
import Foundation
@testable import Brief

@Suite struct ReleaseParsingTests {

    @Test
    func nonCritical() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release")
        #expect(release.critical == false)
    }

    @Test
    func critical() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        #expect(release.critical == true)
    }

    @Test
    func osMissing() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        #expect(release.minimumOSVersion == SemVer("11.0.0"))
    }

    @Test
    func osPresentWithContentBelow() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update ##Minimum macOS Version\n1.2.3\nBuild info")
        #expect(release.minimumOSVersion == SemVer("1.2.3"))
    }

    @Test
    func osPresentAtEnd() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 1.2.3")
        #expect(release.minimumOSVersion == SemVer("1.2.3"))
    }

    @Test
    func osWithMacOSPrefix() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: macOS 1.2.3")
        #expect(release.minimumOSVersion == SemVer("1.2.3"))
    }

    @Test
    func osGreaterThanMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 1.2.3")
        #expect(release.minimumOSVersion < SemVer("11.0.0"))
    }

    @Test
    func osEqualToMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 11.2.3")
        #expect(release.minimumOSVersion <= SemVer("11.2.3"))
    }

    @Test
    func osLessThanMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 1.2.3")
        #expect(release.minimumOSVersion > SemVer("1.0.0"))
    }

    @Test
    func greatestSelectedIfOldPatchIsPublishedLater() async throws {
        // If 2.x.x series has been published, and a patch for 1.x.x is issued
        // 2.x.x should still be selected if user can run it.
        let updater = Updater(checkOnLaunch: false, osVersion: SemVer("2.2.3"), currentVersion: SemVer("1.0.0"))
        let two = Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available! Minimum macOS Version: 2.2.3")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release Minimum macOS Version: 1.2.3"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes Minimum macOS Version: 1.2.3"),
            two,
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch! Minimum macOS Version: 1.2.3"),
        ]

        await updater.evaluate(releases: releases)
        try await Task.sleep(nanoseconds: 1)
        #expect(updater.update == two)
    }

    @Test
    func latestVersionIsRunnable() async throws {
        // If the 2.x.x series has been published but the user can't run it
        // the last version the user can run should be selected.
        let updater = Updater(checkOnLaunch: false, osVersion: SemVer("1.2.3"), currentVersion: SemVer("1.0.0"))
        let oneOhTwo = Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch! Minimum macOS Version: 1.2.3")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release Minimum macOS Version: 1.2.3"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes Minimum macOS Version: 1.2.3"),
            Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available! Minimum macOS Version: 2.2.3"),
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch! Minimum macOS Version: 1.2.3"),
        ]
        await updater.evaluate(releases: releases)
        try await Task.sleep(nanoseconds: 1)
        #expect(updater.update == oneOhTwo)
    }

    @Test
    func sorting() {
        let two = Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available!")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes"),
            two,
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch!"),
        ]
        let sorted = releases.sorted().reversed().first
        #expect(sorted == two)
    }

}
