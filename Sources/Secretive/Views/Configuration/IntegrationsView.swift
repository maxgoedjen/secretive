import SwiftUI

struct IntegrationsView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var selectedInstruction: ConfigurationFileInstructions?
    private let instructions = Instructions()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedInstruction) {
                ForEach(instructions.instructions) { group in
                    Section(group.name) {
                        ForEach(group.instructions) { instruction in
                            Text(instruction.tool)
                                .padding(.vertical, 8)
                                .tag(instruction)
                        }
                    }
                }
            }
        } detail: {
                IntegrationsDetailView(selectedInstruction: $selectedInstruction)
                .fauxToolbar {
                    Button(.setupDoneButton) {
                        dismiss()
                    }
                    .normalButton()
                }
        }
        .onAppear {
            selectedInstruction = instructions.gettingStarted
        }
        .frame(minHeight: 500)
    }

}

extension View {

    func fauxToolbar<Content: View>(content: () -> Content) -> some View {
        modifier(FauxToolbarModifier(toolbarContent: content()))
    }

}

struct FauxToolbarModifier<ToolbarContent: View>: ViewModifier {

    var toolbarContent: ToolbarContent

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content
            Divider()
            HStack {
                Spacer()
                toolbarContent
                .padding(.top, 8)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }

    }

}

struct IntegrationsDetailView: View {

    @Binding private var selectedInstruction: ConfigurationFileInstructions?

    init(selectedInstruction: Binding<ConfigurationFileInstructions?>) {
        _selectedInstruction = selectedInstruction
    }

    var body: some View {
        if let selectedInstruction {
            switch selectedInstruction.id {
            case .gettingStarted:
                GettingStartedView(selectedInstruction: $selectedInstruction)
                case .tool:
                    ToolConfigurationView(selectedInstruction: selectedInstruction)
                case .otherShell:
                    Form {
                        Section {
                            Link(.integrationsViewOtherGithubLink, destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/shells")!)
                        } header: {
                            Text(.integrationsCommunityShellListDescription)
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)

                case .otherApp:
                    Form {
                        Section {
                            Link(.integrationsViewOtherGithubLink, destination: URL(string: "https://github.com/maxgoedjen/secretive-config-instructions/tree/main/apps")!)
                        } header: {
                            Text(.integrationsCommunityAppsListDescription)
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)
                }
        }

    }

}

#Preview {
    IntegrationsView()
        .frame(height: 500)
}
