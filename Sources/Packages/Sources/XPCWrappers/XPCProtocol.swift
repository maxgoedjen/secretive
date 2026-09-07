import Foundation

@objc protocol _XPCProtocol: Sendable {
    func process(_ data: Data, with reply: @Sendable @escaping (Data?, Error?) -> Void)
}

public protocol XPCProtocol<Input, Output>: Sendable {

    associatedtype Input: Codable
    associatedtype Output: Codable

    func process(_ data: Input) async throws -> Output

}
