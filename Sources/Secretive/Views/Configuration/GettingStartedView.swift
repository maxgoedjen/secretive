import SwiftUI

struct GettingStartedView: View {

    private let instructions = Instructions()

    @Binding var selectedInstruction: ConfigurationFileInstructions?

    init(selectedInstruction: Binding<ConfigurationFileInstructions?>) {
        _selectedInstruction = selectedInstruction
    }

    var body: some View {
        Form {
            Section(.integrationsGettingStartedTitle) {
                Text(.integrationsGettingStartedTitleDescription)
            }
            Section {
                Group {
                    Text(.integrationsGettingStartedSuggestionSsh)
                        .onTapGesture {
                            self.selectedInstruction = instructions.ssh
                        }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(.integrationsGettingStartedSuggestionShell)
                        Text(.integrationsGettingStartedSuggestionShellDefault(shellName: String(localized: instructions.defaultShell.tool)))
                            .font(.caption2)
                    }
                    .onTapGesture {
                        self.selectedInstruction = instructions.defaultShell
                    }
                    Text(.integrationsGettingStartedSuggestionGit)
                        .onTapGesture {
                            self.selectedInstruction = instructions.git
                        }
                }
                .foregroundStyle(.link)

            } header: {
                Text(.integrationsGettingStartedWhatShouldIConfigureTitle)
            }
            footer: {
                Text(.integrationsGettingStartedMultipleConfig)
            }
        }
        .formStyle(.grouped)
    }

}
