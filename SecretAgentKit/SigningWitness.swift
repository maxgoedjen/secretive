import Foundation
import SecretKit

public protocol SigningWitness {

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws
    func witness(accessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws

}
