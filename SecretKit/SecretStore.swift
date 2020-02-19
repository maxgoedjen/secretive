import Foundation
import Combine

public protocol SecretStore: ObservableObject {

    associatedtype SecretType: Secret
    var secrets: [SecretType] { get }

}
