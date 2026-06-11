import SwiftUI
import SecretKit
import SecretAgentKit
import SmartCardSecretKit

struct BatchedRequestsView: View {

    let pending: [[SignatureRequest]]
    let review: (Set<SignatureRequest>) async throws -> Void

    init(pending: [[SignatureRequest]], review: @escaping (Set<SignatureRequest>) async throws -> Void) {
        self.pending = pending
        self.review = review
    }

    var body: some View {
        VStack(alignment: .leading) {
//                .padding()
            Form {
//                Text("Multiple authenticated requests are pending. You can approve them batches, or request they all proceed individually.")
                ForEach(Array(pending.enumerated()), id: \.offset) { group in
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
                                        try? await review([pending.element])
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
                                    try? await review(Set(group.element))
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
