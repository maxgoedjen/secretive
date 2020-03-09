import SwiftUI
import SecretKit

struct ContentView: View {
    
    @ObservedObject var storeList: SecretStoreList
    @State var active: AnySecret.ID?
    
    @State var showingDeletion = false
    @State var deletingSecret: AnySecret?
    
    var body: some View {
        NavigationView {
            List(selection: $active) {
                ForEach(storeList.stores) { store in
                    if store.isAvailable {
                        Section(header: Text(store.name)) {
                            ForEach(store.secrets) { secret in
                                NavigationLink(destination: SecretDetailView(secret: secret), tag: secret.id, selection: self.$active) {
                                    Text(secret.name)
                                }.contextMenu {
                                    if store is AnySecretStoreModifiable {
                                        Button(action: { self.delete(secret: secret) }) {
                                            Text("Delete")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.onAppear {
                self.active = self.storeList.stores.compactMap { $0.secrets.first }.first?.id
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, idealWidth: 240)
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .sheet(isPresented: $showingDeletion) {
            if self.storeList.modifiableStore != nil {
                DeleteSecretView(secret: self.deletingSecret!, store: self.storeList.modifiableStore!) {
                    self.showingDeletion = false
                }
            }
        }
        
    }
    
    
    func delete<SecretType: Secret>(secret: SecretType) {
        deletingSecret = AnySecret(secret)
        self.showingDeletion = true
    }
    
}
//
//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(store: Preview.Store(numberOfRandomSecrets: 10))
//    }
//}
