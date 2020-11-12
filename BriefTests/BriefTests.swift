import XCTest
@testable import Brief

class SemVerTests: XCTestCase {

    func testEqual() {
        let current = SemVer("1.0.2")
        let old = SemVer("1.0.2")
        XCTAssert(!(current > old))
    }

    func testPatchGreaterButMinorLess() {
        let current = SemVer("1.1.0")
        let old = SemVer("1.0.2")
        XCTAssert(current > old)
    }

    func testMajorSameMinorGreater() {
        let current = SemVer("1.0.2")
        let new = SemVer("1.0.3")
        XCTAssert(current < new)
    }

    func testMajorGreaterMinorLesser() {
        let current = SemVer("1.0.2")
        let new = SemVer("2.0.0")
        XCTAssert(current < new)
    }

    func testBeta() {
        let current = SemVer("1.0.2")
        let new = SemVer("1.1.0_beta1")
        XCTAssert(current < new)
    }

}
