import Foundation

struct RequireDestinationInformationSettingsKey: SettingsStore.SettingsKey {
    static let defaultValue: Bool = true
}

extension SettingsStore {

    public var requireDestinationInformation: Bool {
        get {
            self[RequireDestinationInformationSettingsKey.self]
        }
        set {
            self[RequireDestinationInformationSettingsKey.self] = newValue
        }
    }

}
