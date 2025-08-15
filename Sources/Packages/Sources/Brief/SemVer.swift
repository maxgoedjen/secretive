import Foundation

/// A representation of a Semantic Version.
public struct SemVer: Sendable {

    /// The SemVer broken into an array of integers.
    let versionNumbers: [Int]

    /// Initializes a SemVer from a string representation.
    /// - Parameter version: A string representation of the SemVer, formatted as "major.minor.patch".
    public init(_ version: String) {
        // Betas have the format 1.2.3_beta1
        let strippedBeta = version.split(separator: "_").first!
        var split = strippedBeta.split(separator: ".").compactMap { Int($0) }
        while split.count < 3 {
            split.append(0)
        }
        versionNumbers = split
    }

    /// Initializes a SemVer from an `OperatingSystemVersion` representation.
    /// - Parameter version: An  `OperatingSystemVersion` representation of the SemVer.
    public init(_ version: OperatingSystemVersion) {
        versionNumbers = [version.majorVersion, version.minorVersion, version.patchVersion]
    }

}

extension SemVer: Comparable {

    public static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        for (latest, current) in zip(lhs.versionNumbers, rhs.versionNumbers) {
            if latest < current {
                return true
            } else if latest > current {
                return false
            }
        }
        return false
    }


}
