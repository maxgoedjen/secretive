import Foundation

/// A protocol for retreiving the latest available version of an app.
public protocol UpdaterProtocol: ObservableObject {

    /// The latest update
    @MainActor var update: Release? { get }
    /// A boolean describing whether or not the current build of the app is a "test" build (ie, a debug build or otherwise special build)
    @MainActor var testBuild: Bool { get }

}

