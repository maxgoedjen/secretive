import Foundation
import Combine

class PreviewUpdater: ObservableObject, UpdaterProtocol {
    var update: Release? = nil
}
