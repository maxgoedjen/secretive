import SecretKit
import SecretAgentKit

struct StubWitness {

    let speakNow: @Sendable (AnySecret, SigningRequestProvenance) -> Bool
    let witness: @Sendable (AnySecret, SigningRequestProvenance) -> ()

}

extension StubWitness: SigningWitness {

    func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance, target: SigningRequestTarget?) throws {
        let objection = speakNow(secret, provenance)
        if objection {
            throw TheresMyChance()
        }
    }

func witness(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance, target: SigningRequestTarget?) throws {
        witness(secret, provenance)
    }

}

extension StubWitness {

    struct TheresMyChance: Error {

    }

}
