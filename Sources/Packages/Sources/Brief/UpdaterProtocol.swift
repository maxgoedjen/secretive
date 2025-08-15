import Foundation
import os

/// A protocol for retreiving the latest available version of an app.
public protocol UpdaterProtocol: Observable, Sendable {

    /// The latest update
    var update: Release? { get }
    /// A boolean describing whether or not the current build of the app is a "test" build (ie, a debug build or otherwise special build)
    var testBuild: Bool { get }

    func ignore(release: Release) async
}

