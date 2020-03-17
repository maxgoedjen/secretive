import Foundation
import SecretKit

public protocol SigningWitness {

    func witness(accessTo secret: AnySecret, by provenance: SigningRequestProvenance) throws

}
