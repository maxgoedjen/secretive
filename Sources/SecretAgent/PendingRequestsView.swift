import SwiftUI
import SecretKit
import SecretAgentKit
import SmartCardSecretKit
import Common

struct PendingRequestsView: View {

    private let authenticationHandler: any AuthenticationHandlerProtocol
    @Environment(\.dismissWindow) var dismiss

    init(authenticationHandler: some AuthenticationHandlerProtocol) {
        self.authenticationHandler = authenticationHandler
    }

    var body: some View {
        ScrollView {
            Text(.pendingRequestDescription)
            ForEach(Array(authenticationHandler.batchableRequests.enumerated()), id: \.offset) { group in
                MultilineInfoView {
                    if let first = group.element.first {
                        HStack {
                            HStack {
                                Image(nsImage: .init(byReferencing: first.provenance.origin.iconURL!))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50)
                                VStack(alignment: .leading) {
                                    Text(first.provenance.origin.displayName)
                                        .font(.subheadline)
                                    Text(first.secret.name)
                                        .font(.headline)
                                    switch first.target {
                                    case .connection(let payload):
                                        if let host = payload.host {
                                            Text(.authContextConnectingToUsernameAndHost(username: payload.username, host: host))
                                                .font(.caption2)
                                        } else {
                                            Text(.authContextConnectingToUnknownHost)
                                                .font(.caption2)
                                        }
                                    case .signature(let payload):
                                        Text(.authContextSigningForNamespace(namespace: payload.namespace))
                                            .font(.caption2)
                                    default:
                                        EmptyView()
                                    }
                                }
                            }
                            Spacer()
                            VStack {
                                Button(.pendingRequestsReviewBatchButton) {
                                    Task {
                                        try? await authenticationHandler.requestAuthentication(for: Set(group.element))
                                        if authenticationHandler.batchableRequests.isEmpty {
                                            dismiss()
                                        }
                                    }
                                }
                                .buttonBorderShape(.capsule)
                                .primaryButton()
                            }
                        }
                    }
                } items: {
                    ForEach(Array(group.element.enumerated()), id: \.offset) { pending in
                        HStack {
                            Text(pending.element.provenance.date.formatted())
                            Spacer()
                            Button(.pendingRequestsReviewSingleButton) {
                                Task {
                                    try? await authenticationHandler.requestAuthentication(for: [pending.element])
                                    if authenticationHandler.batchableRequests.isEmpty {
                                        dismiss()
                                    }
                                }
                            }
                            .buttonBorderShape(.capsule)
                            .normalButton()
                        }
                    }

                }
            }
        }
        .safeAreaPadding(20)
    }

}

private struct TestHandler: AuthenticationHandlerProtocol {

    var batchableRequests: [[SignatureRequest]] = []

    func requestAuthentication(for requests: Set<SignatureRequest>) async throws {

    }

    func persistAuthentication<SecretType>(secret: SecretType, forDuration duration: TimeInterval) async throws where SecretType : Secret {

    }

    func setPendingRequestHandler(_ handler: @escaping () async throws -> Void) {

    }
    
    func authenticatedContext(for request: SignatureRequest, context: any AuthenticationContextProtocol) async throws -> (any AuthenticationContextProtocol)? {
        nil
    }

}


    #Preview {
        if #available(macOS 26.0, *) {
            ScrollView {
                MultilineInfoView {
                    HStack {
                        HStack {
                            Image("ghostty")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50)
                            VStack(alignment: .leading) {
                                Text("Ghostty")
                                    .font(.subheadline)
                                Text("GitHub")
                                    .font(.headline)
                                Text("Authenticating git@github.com")
                                    .font(.caption2)
                            }
                        }
                        Spacer()
                        VStack {
                            Button("Review as Batch") {

                            }
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.glassProminent)
                        }
                    }
                } items: {
                    ForEach(0..<2) { _ in
                        HStack {
                            Text("4:05 PM")
                            Spacer()
                            Button("Review") {

                            }
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.glass)
                        }
                    }

                }
                MultilineInfoView {
                    HStack {
                        HStack {
                            Image("ghostty")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50)
                            VStack(alignment: .leading) {
                                Text("Ghostty")
                                    .font(.subheadline)
                                Text("Git Signing")
                                    .font(.headline)
                                Text("Git Signature")
                                    .font(.caption2)
                            }
                        }
                        Spacer()
                        VStack {
                            Button("Review as Batch") {

                            }
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.glassProminent)
                        }
                    }
                } items: {
                    ForEach(0..<2) { _ in
                        HStack {
                            Text("4:05 PM")
                            Spacer()
                            Button("Review") {

                            }
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.glass)
                        }
                    }

                }

            }
            .padding()
            .formStyle(.grouped)
            .frame(minHeight: 700)
        }

    }
