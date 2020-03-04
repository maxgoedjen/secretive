import SwiftUI
import SecretKit

struct ContentView<StoreType: SecretStore>: View {

    @ObservedObject var store: StoreType

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(store.name)) {
                    ForEach(store.secrets) { secret in
                        NavigationLink(destination: SecretDetailView(secret: secret)) {
                            Text(secret.name)
                        }.contextMenu {
                            Button(action: { self.delete(secret: secret) }) {
                                Text("Delete")
                            }
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 100, idealWidth: 240)
        }.navigationViewStyle(DoubleColumnNavigationViewStyle())
    }


    func delete(secret: StoreType.SecretType) {
        // TODO: Add "type the name of the key to delete" dialogue
        try! store.delete(secret: secret)
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: Preview.Store(numberOfRandomSecrets: 10))
    }
}
