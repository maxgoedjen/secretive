import XCTest
@testable import Brief

class ReleaseParsingTests: XCTestCase {

    func testNonCritical() {

    }

    func testCritical() {

    }

    func testOSGreaterThanMinimum() {

    }

    func testOSLessThanMinimum() {

    }

    func testGreatestSelectedIfOldPatchIsPublishedLater() {
        // If 2.x.x series has been published, and a patch for 1.x.x is issued
        // 2.x.x should still be selected if user can run it.
    }

    func testLatestVersionIsRunnable() {
        // If the 2.x.x series has been published but the user can't run it
        // the last version the user can run should be selected.
    }

}
