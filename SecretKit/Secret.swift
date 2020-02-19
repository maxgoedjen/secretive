import Foundation

public protocol Secret: Identifiable, Hashable {
    var id: String { get }
}
