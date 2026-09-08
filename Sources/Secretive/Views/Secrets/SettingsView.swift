import SwiftUI
import SettingsKit

struct SettingsView: View {

    @Environment(\.settingsStore) var settingsStore

    var body: some View {
        Form {
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
    }
}
