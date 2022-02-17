import Foundation
import Brief

@objc public protocol UpdaterProtocol {

    func installUpdate(url: URL, to: URL) async throws -> String

}
