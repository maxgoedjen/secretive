import SwiftUI
import SecretKit

struct ContentView: View {
    
    @ObservedObject var store: SecureEnclave.Store
    @State var active: SecureEnclave.Secret?
    
    @State var showingDeletion = false
    @State var deletingSecret: SecureEnclave.Secret?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(store.name)) {
                    ForEach(store.secrets) { secret in
                        NavigationLink(destination: SecretDetailView(secret: secret), tag: secret, selection: self.$active) {
                            Text(secret.name)
                        }.contextMenu {
                            Button(action: { self.delete(secret: secret) }) {
                                Text("Delete")
                            }
                        }
                    }
                }
            }.onAppear {
                self.active = self.store.secrets.first
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, idealWidth: 240)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .sheet(isPresented: $showingDeletion) {
            DeleteSecretView(secret: self.deletingSecret!, store: self.store) {
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
