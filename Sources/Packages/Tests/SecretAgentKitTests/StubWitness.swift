import SecretKit
import SecretAgentKit

struct StubWitness {

    let speakNow: (AnySecret, SigningRequestProvenance) -> Bool
    let witness: (AnySecret, SigningRequestProvenance) -> ()

}

extension StubWitness: SigningWitness {

func speakNowOrForeverHoldYourPeace(forAccessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance) throws {
        let objection = speakNow(secret, provenance)
        if objection {
            throw TheresMyChance()
        }
    }

func witness(accessTo secret: AnySecret, from store: AnySecretStore, by provenance: SigningRequestProvenance, requiredAuthentication: Bool) throws {
        witness(secret, provenance)
    }

}

extension StubWitness {

    struct TheresMyChance: Error {

    }

}
