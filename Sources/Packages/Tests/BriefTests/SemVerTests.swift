import Testing
import Foundation
@testable import Brief

@Suite struct SemVerTests {

    @Test func equal() {
        let current = SemVer("1.0.2")
        let old = SemVer("1.0.2")
        #expect(!(current > old))
    }

    @Test func patchGreaterButMinorLess() {
        let current = SemVer("1.1.0")
        let old = SemVer("1.0.2")
        #expect(current > old)
    }

    @Test func majorSameMinorGreater() {
        let current = SemVer("1.0.2")
        let new = SemVer("1.0.3")
        #expect(current < new)
    }

    @Test func majorGreaterMinorLesser() {
        let current = SemVer("1.0.2")
        let new = SemVer("2.0.0")
        #expect(current < new)
    }

    @Test func regularParsing() {
        let current = SemVer("1.0.2")
        #expect(current.versionNumbers == [1, 0, 2])
    }

    @Test func noPatch() {
        let current = SemVer("1.1")
        #expect(current.versionNumbers == [1, 1, 0])
    }

    @Test func garbage() {
        let current = SemVer("Test")
        #expect(current.versionNumbers == [0, 0, 0])
    }

    @Test func beta() {
        let current = SemVer("1.0.2")
        let new = SemVer("1.1.0_beta1")
        #expect(current < new)
    }

}
