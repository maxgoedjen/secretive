import SwiftUI

struct SetupView: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var setupComplete: Bool

    @State var showingIntegrations = false
    @State var buttonWidth: CGFloat?

    @State var installed = false
    @State var updates = false
    @State var integrations = false
    var allDone: Bool {
        installed && updates && integrations
    }

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 0) {
                StepView(
                    title: "setup_agent_title",
                    description: "setup_agent_description",
                    systemImage: "lock.laptopcomputer",
                ) {
                    OnboardingButton("setup_agent_install_button", installed, width: buttonWidth) {
                        Task {
                            installed = await LaunchAgentController().install()
                        }
                    }
                }
                Divider()
                StepView(
                    title: "setup_updates_title",
                    description: "setup_updates_description",
                    systemImage: "network.badge.shield.half.filled",
                ) {
                    OnboardingButton("setup_updates_ok", updates, width: buttonWidth) {
                        updates = true
                    }
                }
                Divider()
                StepView(
                    title: "Configure Integrations",
                    description: "Tell the tools you use how to talk to Secretive.",
                    systemImage: "firewall",
                ) {
                    OnboardingButton("Configure", integrations, width: buttonWidth) {
                        showingIntegrations = true
                    }
                }
            }
            .onPreferenceChange(OnboardingButton.WidthKey.self) { width in
                buttonWidth = width
            }
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .frame(minWidth: 700, maxWidth: .infinity)
            HStack {
                Spacer()
                Button("Done") {
                    setupComplete = true
                    dismiss()
                }
                .disabled(!allDone)
                .primaryButton()
            }
        }
        .interactiveDismissDisabled()
        .padding()
        .sheet(isPresented: $showingIntegrations, onDismiss: {
            integrations = true
        }, content: {
            IntegrationsView()
        })
    }
}

struct OnboardingButton: View {

    struct WidthKey: @MainActor PreferenceKey {
        @MainActor static var defaultValue: CGFloat? = nil
        static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
            if let next = nextValue(), next > (value ?? -1) {
                value = next
            }
        }

    }

    let label: LocalizedStringResource
    let complete: Bool
    let action: () -> Void
    let width: CGFloat?
    @State var currentWidth: CGFloat?

    init(_ label: LocalizedStringResource, _ complete: Bool, width: CGFloat? = nil, action: @escaping () -> Void) {
        self.label = label
        self.complete = complete
        self.action = action
        self.width = width
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if complete {
                    Text("Done")
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Text(label)
                }
            }
            .frame(width: width)
            .padding(.vertical, 2)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newValue in
                currentWidth = newValue
            }
        }
        .preference(key: WidthKey.self, value: currentWidth)
        .primaryButton()
        .disabled(complete)
        .tint(complete ? .green : nil)
    }
        
}

struct StepView<Content: View>: View {
    
    let title: LocalizedStringResource
    let icon: Image
    let description: LocalizedStringResource
    let actions: Content
    
    init(title: LocalizedStringResource, description: LocalizedStringResource, systemImage: String, actions: () -> Content) {
        self.title = title
        self.icon = Image(systemName: systemImage)
        self.description = description
        self.actions = actions()
    }
    
    var body: some View {
        HStack(spacing: 20) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .bold()
                Text(description)
            }
            Spacer()
            actions
        }
        .padding(20)
    }
    
}

extension SetupView {

    enum Constants {
        static let updaterFAQURL = URL(string: "https://github.com/maxgoedjen/secretive/blob/main/FAQ.md#whats-this-network-request-to-github")!
    }

}

#Preview {
    SetupView(setupComplete: .constant(false))
}
