import Foundation
import SecretKit

public protocol SigningWitness {

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) throws
    func witness(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) throws

}
