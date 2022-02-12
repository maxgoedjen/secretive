import Foundation
import Brief

@objc public protocol UpdaterProtocol {

    func installUpdate(url: URL) async throws -> String
    func authorize() async throws

}
