import Foundation
import SwiftUI

/// A release is a representation of a downloadable update.
public struct Release: Codable, Sendable, Hashable {

    /// The user-facing name of the release. Typically "Secretive 1.2.3"
    public let name: String

    /// A boolean describing whether or not the release is a prerelase build.
    public let prerelease: Bool

    /// A URL pointing to the HTML page for the release.
    public let html_url: URL

    /// A user-facing description of the contents of the update.
    public let body: String

    public let attributedBody: AttributedString

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
        self.attributedBody = AttributedString(_markdown: body)
    }

    public init(_ release: GitHubRelease) {
        self.name = release.name
        self.prerelease = release.prerelease
        self.html_url = release.html_url
        self.body = release.body
        self.attributedBody = AttributedString(_markdown: release.body)
    }

}

public struct GitHubRelease: Codable, Sendable {
    let name: String
    let prerelease: Bool
    let html_url: URL
    let body: String
}

fileprivate extension AttributedString {

    init(_markdown markdown: String) {
        let split = markdown.split(whereSeparator: \.isNewline)
        let lines = split
            .compactMap {
                try? AttributedString(markdown: String($0), options: .init(allowsExtendedAttributes: true, interpretedSyntax: .full))
            }
            .map { (string: AttributedString) in
                guard case let .header(level) = string.runs.first?.presentationIntent?.components.first?.kind else { return string }
                return AttributedString("\n") + string
                    .transformingAttributes(\.font) { font in
                        font.value = switch level {
                        case 2: .headline.bold()
                        case 3: .headline
                        default: .subheadline
                        }
                    }
                    .transformingAttributes(\.underlineStyle) { underline in
                        underline.value = switch level {
                        case 2: .single
                        default: .none
                        }
                    }
                + AttributedString("\n")
            }
        self = lines.reduce(into: AttributedString()) { partialResult, next in
            partialResult.append(next)
            partialResult.append(AttributedString("\n"))
        }
    }

}

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
