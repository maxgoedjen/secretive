import Foundation

struct RequireDestinationInformationSettingsKey: SettingsStore.SettingsKey {
    static let defaultValue: Bool = true
}

extension SettingsStore {

    public var requireDestinationInformation: Bool {
        get { self[RequireDestinationInformationSettingsKey.self] }
        set { self[RequireDestinationInformationSettingsKey.self] = newValue }
    }

}

struct MultipleRequestScreenEnabledSettingsKey: SettingsStore.SettingsKey {
    static let defaultValue: Bool = true
}

extension SettingsStore {

    public var multipleRequestScreenEnabled: Bool {
        get { self[MultipleRequestScreenEnabledSettingsKey.self] }
        set { self[MultipleRequestScreenEnabledSettingsKey.self] = newValue }
    }

}

struct MultipleRequestScreenCountThresholdSettingsKey: SettingsStore.SettingsKey {
    static let defaultValue: Int = 2
}

extension SettingsStore {

    public var multipleRequestScreenCountThreshold: Int {
        get { self[MultipleRequestScreenCountThresholdSettingsKey.self] }
        set { self[MultipleRequestScreenCountThresholdSettingsKey.self] = newValue }
    }

}

struct ShowDockItemWithPendingRequestsScreenSettingsKey: SettingsStore.SettingsKey {
    static let defaultValue: Bool = true
}

extension SettingsStore {

    public var showDockItemWithPendingRequestsScreen: Bool {
        get { self[ShowDockItemWithPendingRequestsScreenSettingsKey.self] }
        set { self[ShowDockItemWithPendingRequestsScreenSettingsKey.self] = newValue }
    }

}

