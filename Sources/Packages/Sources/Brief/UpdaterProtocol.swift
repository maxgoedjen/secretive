import Foundation

/// A protocol for retreiving the latest available version of an app.
public protocol UpdaterProtocol: Observable, Sendable {

    /// The latest update
    @MainActor var update: Release? { get }

    var currentVersion: SemVer { get }

    func ignore(release: Release) async
}

