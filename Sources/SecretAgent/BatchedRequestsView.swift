import SwiftUI
import SecretKit
import SecretAgentKit
import SmartCardSecretKit
import Common

struct BatchedRequestsView: View {

    private let authenticationHandler: any AuthenticationHandlerProtocol

    init(authenticationHandler: some AuthenticationHandlerProtocol) {
        self.authenticationHandler = authenticationHandler
    }

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Text("Multiple authenticated requests are pending. You can approve them batches, or request they all proceed individually.")
                ForEach(Array(authenticationHandler.batchableRequests.enumerated()), id: \.offset) { group in
                    Section {
                        ForEach(Array(group.element.enumerated()), id: \.offset) { pending in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(pending.element.provenance.origin.displayName)
                                        .font(.headline)
                                    Text(pending.element.provenance.date.formatted())
                                        .font(.footnote)
                                }
                                Spacer()
                                Button("Review") {
                                    Task {
                                        try? await authenticationHandler.requestAuthentication(for: [pending.element])
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("\(group.element.first!.provenance.origin.displayName) - \(group.element.first!.secret.name)")
                            Spacer()
                            Button("Review All") {
                                Task {
                                    try? await authenticationHandler.requestAuthentication(for: Set(group.element))
                                }

                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct TestHandler: AuthenticationHandlerProtocol {

    var batchableRequests: [[SignatureRequest]] = []

    func requestAuthentication(for requests: Set<SignatureRequest>) async throws {

    }

    func persistAuthentication<SecretType>(secret: SecretType, forDuration duration: TimeInterval) async throws where SecretType : Secret {

    }

    func setBatchAuthHandler(_ handler: @escaping () async throws -> Void) {

    }

    func waitForAuthentication(for request: SignatureRequest) async throws -> any AuthenticationContextProtocol {
        fatalError()
    }

}
//
//#Preview {
//    ScrollView {
//        MultilineInfoView(title: "GitHub", subtitle: "Ghostty", image: Image(systemName: "lock"), items: [
//            "
//        ])
////        Section {
////            ForEach(0..<2) { _ in
////                VStack(alignment: .leading) {
////                    Text("Ghostty")
////                        .font(.headline)
////                    Text("zsh 􀯻 git 􀯻 zsh")
////                        .font(.footnote)
////                    Text("4:05 PM")
////                }
////            }
////        } header: {
////            Text("GitHub")
////        }
////        Section {
////            ForEach(0..<2) { _ in
////                VStack(alignment: .leading) {
////                    Text("Ghostty")
////                        .font(.headline)
////                    Text("zsh 􀯻 git")
////                        .font(.footnote.monospaced())
////                    Text("Git Signature")
////                        .font(.footnote)
////                    Text("4:05 PM")
////                        .font(.caption)
////                }
////            }
////        } header: {
////            Text("GitHub Signing Key")
////        }
//    }
//    .padding()
//    .formStyle(.grouped)
//    .frame(minHeight: 700)
//}
