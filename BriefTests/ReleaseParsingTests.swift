import XCTest
@testable import Brief

class ReleaseParsingTests: XCTestCase {

    func testNonCritical() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release")
        XCTAssert(release.critical == false)
    }

    func testCritical() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        XCTAssert(release.critical == true)
    }

    func testOSMissing() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        XCTAssert(release.minimumOSVersion == SemVer("11.0.0"))
    }

    func testOSPresent() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Requires macOS 11.0.0")
        XCTAssert(release.minimumOSVersion == SemVer("11.0.0"))
    }

    func testOSGreaterThanMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        XCTAssert(release.minimumOSVersion < SemVer("11.0.0"))
    }

    func testOSEqualToMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        XCTAssert(release.minimumOSVersion <= SemVer("11.0.0"))
    }

    func testOSLessThanMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update")
        XCTAssert(release.minimumOSVersion > SemVer("10.0.0"))
    }

    func testGreatestSelectedIfOldPatchIsPublishedLater() {
        // If 2.x.x series has been published, and a patch for 1.x.x is issued
        // 2.x.x should still be selected if user can run it.
        let updater = Updater(checkOnLaunch: false, osVersion: SemVer("10.0.0"))
        let two = Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available!")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes"),
            two,
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch!"),
        ]
        updater.evaluate(releases: releases)
        XCTAssert(updater.update == two)
    }

    func testLatestVersionIsRunnable() {
        // If the 2.x.x series has been published but the user can't run it
        // the last version the user can run should be selected.
        let updater = Updater(checkOnLaunch: false, osVersion: SemVer("10.0.0"))
        let oneOhTwo = Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch!")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes"),
            Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available!"),
            oneOhTwo,
        ]
        updater.evaluate(releases: releases)
        XCTAssert(updater.update == oneOhTwo)
    }

    func testSorting() {
        let two = Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available!")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes"),
            two,
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch!"),
        ]
        let sorted = releases.sorted().reversed().first
        XCTAssert(sorted == two)
    }

}
