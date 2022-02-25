import Foundation
import SecretKit

/// A protocol that allows conformers to be notified of access to secrets, and optionally prevent access.
public protocol SigningWitness {

    /// A ridiculously named method that notifies the callee that a signing operation is about to be performed using a secret. The callee may `throw` an `Error` to prevent access from occurring.
    /// - Parameters:
    ///   - secret: The `Secret` that will be used to sign the request.
    ///   - store: The `Store` being asked to sign the request..
    ///   - provenance: A `SigningRequestProvenance` object describing the origin of the request.
    ///   - Note: This method being called does not imply that the requst has been authorized. If a secret requires authentication, authentication will still need to be performed by the user before the request will be performed. If the user declines or fails to authenticate, the request will fail.
    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) throws

    /// Notifies the callee that a signing operation has been performed for a given secret.
    /// - Parameters:
    ///   - secret: The `Secret` that will was used to sign the request.
    ///   - store: The `Store` that signed the request..
    ///   - provenance: A `SigningRequestProvenance` object describing the origin of the request.
    func witness(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) throws

}
