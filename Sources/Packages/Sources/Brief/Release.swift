import Foundation

/// A release is a representation of a downloadable update.
public struct Release: Codable, Sendable {

    /// The user-facing name of the release. Typically "Secretive 1.2.3"
    public let name: String

    /// A boolean describing whether or not the release is a prerelase build.
    public let prerelease: Bool

    /// A URL pointing to the HTML page for the release.
    public let html_url: URL

    /// A user-facing description of the contents of the update.
    public let body: String

    /// Initializes a Release.
    /// - Parameters:
    ///   - name: The user-facing name of the release.
    ///   - prerelease: A boolean describing whether or not the release is a prerelase build.
    ///   - html_url: A URL pointing to the HTML page for the release.
    ///   - body: A user-facing description of the contents of the update.
    public init(name: String, prerelease: Bool, html_url: URL, body: String) {
        self.name = name
        self.prerelease = prerelease
        self.html_url = html_url
        self.body = body
    }

}

// TODO: REMOVE WHEN(?) URL GAINS NATIVE CONFORMANCE
extension URL: @unchecked Sendable {}

extension Release: Identifiable {

    public var id: String {
        html_url.absoluteString
    }

}

extension Release: Comparable {

    public static func < (lhs: Release, rhs: Release) -> Bool {
        lhs.version < rhs.version
    }

}

extension Release {

    /// A boolean describing whether or not the release contains critical security content.
    /// - Note: this is determined by the presence of the phrase "Critical Security Update" in the ``body``.
    /// - Warning: If this property is true, the user will not be able to dismiss UI or reminders associated with the update.
    public var critical: Bool {
        body.contains(Constants.securityContent)
    }

    /// A ``SemVer`` representation of the version number of the release.
    public var version: SemVer {
        SemVer(name)
    }

    /// The minimum macOS version required to run the update.
    public var minimumOSVersion: SemVer {
        guard let range = body.range(of: "Minimum macOS Version"),
              let numberStart = body.rangeOfCharacter(from: CharacterSet.decimalDigits, options: [], range: range.upperBound..<body.endIndex) else { return SemVer("11.0.0") }
        let numbersEnd = body.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines, options: [], range: numberStart.upperBound..<body.endIndex)?.lowerBound ?? body.endIndex
        let version = numberStart.lowerBound..<numbersEnd
        return SemVer(String(body[version]))
    }

}

extension Release {

    enum Constants {
        static let securityContent = "Critical Security Update"
    }

}
