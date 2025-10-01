import SwiftUI

struct SetupView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.agentLaunchController) private var agentLaunchController
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
                    title: .setupAgentTitle,
                    description: .setupAgentDescription,
                    detail: .setupAgentActivityMonitorDescription,
                    systemImage: "lock.laptopcomputer",
                ) {
                    SetupButton(
                        .setupAgentInstallButton,
                        complete: installed,
                        width: buttonWidth
                    ) {
                        installed = true
                        Task {
                            try? await agentLaunchController.install()
                        }
                    }
                }
                Divider()
                StepView(
                    title: .setupUpdatesTitle,
                    description: .setupUpdatesDescription,
                    systemImage: "network.badge.shield.half.filled",
                ) {
                    SetupButton(
                        .setupUpdatesOkButton,
                        complete: updates,
                        width: buttonWidth
                    ) {
                        updates = true
                    }
                }
                Divider()
                StepView(
                    title: .setupIntegrationsTitle,
                    description: .setupIntegrationsDescription,
                    systemImage: "firewall",
                ) {
                    SetupButton(
                        .setupIntegrationsButton,
                        complete: integrations,
                        width: buttonWidth
                    ) {
                        showingIntegrations = true
                    }
                }
            }
            .onPreferenceChange(SetupButton.WidthKey.self) { width in
                buttonWidth = width
            }
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .frame(minWidth: 600, maxWidth: .infinity)
            HStack {
                Spacer()
                Button(.setupDoneButton) {
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
                .frame(minWidth: 500, minHeight: 400)
        })
        .frame(idealWidth: 600)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct SetupButton: View {

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

    init(_ label: LocalizedStringResource, complete: Bool, width: CGFloat? = nil, action: @escaping () -> Void) {
        self.label = label
        self.complete = complete
        self.action = action
        self.width = width
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if complete {
                    Text(.setupStepCompleteButton)
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
    let detail: LocalizedStringResource?
    let actions: Content
    
    init(
        title: LocalizedStringResource,
        description: LocalizedStringResource,
        detail: LocalizedStringResource? = nil,
        systemImage: String,
        actions: () -> Content
    ) {
        self.title = title
        self.icon = Image(systemName: systemImage)
        self.description = description
        self.detail = detail
        self.actions = actions()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24)
            Spacer()
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .bold()
                Text(description)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout)
                        .italic()
                }
            }
            Spacer(minLength: 20)
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
