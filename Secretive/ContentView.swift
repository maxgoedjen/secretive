//
//  ContentView.swift
//  Secretive
//
//  Created by Max Goedjen on 2/18/20.
//  Copyright © 2020 Max Goedjen. All rights reserved.
//

import SwiftUI
import SecretKit

struct ContentView<StoreType: SecretStore>: View {

    @ObservedObject var store: StoreType

    @State var pk: String = ""

    var body: some View {
        HSplitView {
            List {
                ForEach(store.secrets) { secret in
                    Text(secret.id)
                }
            }.listStyle(SidebarListStyle())
            Form {
                Text("Public Key")
            }
        }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: Preview.Store(numberOfRandomSecrets: 10))
    }
}

