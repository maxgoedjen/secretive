public protocol Secret: Identifiable, Hashable {

    var name: String { get }
    var publicKey: Data { get }

}
