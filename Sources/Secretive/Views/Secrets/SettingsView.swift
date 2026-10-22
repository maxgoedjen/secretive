import SwiftUI
import SettingsKit

struct SettingsView: View {

    @Environment(\.settingsStore) var settingsStore

    var body: some View {
        @Bindable var settingsStore = settingsStore
        Form {
            Toggle(.settingsPlaySoundForAutomaticApprovalRequests, isOn: $settingsStore.playSoundForAutomaticApprovalRequests)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
    }
}
