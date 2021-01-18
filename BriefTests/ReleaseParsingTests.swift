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

    func testOSPresentWithContentBelow() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update ##Minimum macOS Version\n1.2.3\nBuild info")
        XCTAssert(release.minimumOSVersion == SemVer("1.2.3"))
    }

    func testOSPresentAtEnd() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 1.2.3")
        XCTAssert(release.minimumOSVersion == SemVer("1.2.3"))
    }

    func testOSGreaterThanMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 1.2.3")
        XCTAssert(release.minimumOSVersion < SemVer("11.0.0"))
    }

    func testOSEqualToMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 11.2.3")
        XCTAssert(release.minimumOSVersion <= SemVer("11.2.3"))
    }

    func testOSLessThanMinimum() {
        let release = Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Critical Security Update Minimum macOS Version: 1.2.3")
        XCTAssert(release.minimumOSVersion > SemVer("1.0.0"))
    }

    func testGreatestSelectedIfOldPatchIsPublishedLater() {
        // If 2.x.x series has been published, and a patch for 1.x.x is issued
        // 2.x.x should still be selected if user can run it.
        let updater = Updater(checkOnLaunch: false, osVersion: SemVer("2.2.3"))
        let two = Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available! Minimum macOS Version: 2.2.3")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release Minimum macOS Version: 1.2.3"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes Minimum macOS Version: 1.2.3"),
            two,
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch! Minimum macOS Version: 1.2.3"),
        ]

        let expectation = XCTestExpectation()
        updater.evaluate(releases: releases)
        DispatchQueue.main.async {
            XCTAssert(updater.update == two)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testLatestVersionIsRunnable() {
        // If the 2.x.x series has been published but the user can't run it
        // the last version the user can run should be selected.
        let updater = Updater(checkOnLaunch: false, osVersion: SemVer("1.2.3"))
        let oneOhTwo = Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch! Minimum macOS Version: 1.2.3")
        let releases = [
            Release(name: "1.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Initial release Minimum macOS Version: 1.2.3"),
            Release(name: "1.0.1", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Bug fixes Minimum macOS Version: 1.2.3"),
            Release(name: "2.0.0", prerelease: false, html_url: URL(string: "https://example.com")!, body: "2.0 available! Minimum macOS Version: 2.2.3"),
            Release(name: "1.0.2", prerelease: false, html_url: URL(string: "https://example.com")!, body: "Emergency patch! Minimum macOS Version: 1.2.3"),
        ]
        let expectation = XCTestExpectation()
        updater.evaluate(releases: releases)
        DispatchQueue.main.async {
            XCTAssert(updater.update == oneOhTwo)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
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
