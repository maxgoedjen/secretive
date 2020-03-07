import SwiftUI
import SecretKit

struct ContentView: View {
    
    @ObservedObject var secureEnclave: SecureEnclave.Store
    @ObservedObject var smartCard: SmartCard.Store
    @State var active: Data?
    
    @State var showingDeletion = false
    @State var deletingSecret: SecureEnclave.Secret?
    
    var body: some View {
        NavigationView {
            List(selection: $active) {
                Section(header: Text(secureEnclave.name)) {
                    ForEach(secureEnclave.secrets) { secret in
                        NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: self.$active) {
                            Text(secret.name)
                        }.contextMenu {
                            Button(action: { self.delete(secret: secret) }) {
                                Text("Delete")
                            }
                        }
                    }
                }
                Section(header: Text(smartCard.name)) {
                    ForEach(smartCard.secrets) { secret in
                        NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: self.$active) {
                            Text(secret.name)
                        }
                    }
                }
            }.onAppear {
                self.active = self.secureEnclave.secrets.first?.id ?? self.smartCard.secrets.first?.id
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, idealWidth: 240)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .sheet(isPresented: $showingDeletion) {
            DeleteSecretView(secret: self.deletingSecret!, store: self.secureEnclave) {
                self.showingDeletion = false
            }
        }
        
    }
    
    
    func delete(secret: SecureEnclave.Secret) {
        deletingSecret = secret
        showingDeletion = true
    }
    
}
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(store: Preview.Store(numberOfRandomSecrets: 10))
//    }
//}
