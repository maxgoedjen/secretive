import SecretKit

class StubStore: SecretStore {

    var isAvailable: Bool = true
    let id = UUID()
    let name = "Stub Store"
    var secrets: [SmartCard.Secret] = []
    fileprivate var smartCardStore = SmartCard.Store()

    func sign(data: Data, with secret: SmartCard.Secret) throws -> Data {
        try smartCardStore.sign(data: data, with: secret)
    }

}
