import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable>: View {
    
    @ObservedObject var store: StoreType
    @Binding var showing: Bool
    
    @State private var name = ""
    @State private var requiresAuthentication = true
    @State private var test: ThumbnailPickerView.Item = ThumbnailPickerView.Item(name: "Test", thumbnail: Text("Hello"))
    
    var body: some View {
        VStack {
            HStack {
                VStack {
                    HStack {
                        Text("Create a New Secret")
                            .font(.largeTitle)
                        Spacer()
                    }
                    HStack {
                        Text("Name:")
                        TextField("Shhhhh", text: $name)
                            .focusable()
                    }
                    ThumbnailPickerView(items: [
                        ThumbnailPickerView.Item(name: "Requires Authentication Before Use", thumbnail: Text("")),
                        ThumbnailPickerView.Item(name: "Notify on Use", thumbnail: Text(""))
                    ], selection: $test)
                    //                    HStack {
                    //                        VStack(spacing: 20) {
                    //                            Picker("", selection: $requiresAuthentication) {
                    //                                Text("Requires Authentication (Biometrics or Password) before each use").tag(true)
                    //                                Text("Authentication not required when Mac is unlocked").tag(false)
                    //                            }
                    //                            .pickerStyle(SegmentedPickerStyle())
                    //                        }
                    //                        Spacer()
                    //                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    showing = false
                }
                .keyboardShortcut(.cancelAction)
                Button("Create", action: save)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }.padding()
    }
    
    func save() {
        try! store.create(name: name, requiresAuthentication: requiresAuthentication)
        showing = false
    }
}

struct ThumbnailPickerView: View {
    
    let items: [Item]
    let selection: Binding<Item>
    
    var body: some View {
        HStack {
            ForEach(items) { item in
                Text(item.name)
            }
        }
    }
    
}

extension ThumbnailPickerView {
    
    struct Item: Identifiable {
        let id = UUID()
        let name: String
        let thumbnail: AnyView
        
        init<ViewType: View>(name: String, thumbnail: ViewType) {
            self.name = name
            self.thumbnail = AnyView(thumbnail)
        }
    }
    
}

@available(macOS 12.0, *)
struct AuthenticationView: View {
    
    var body: some View {
        ZStack {
            if let mainScreen = NSScreen.main, let imageURL = NSWorkspace.shared.desktopImageURL(for: mainScreen) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty, .failure:
                        Rectangle()
                            .foregroundColor(Color(.systemPurple))
                    case .success(let image):
                        image
                            .resizable()
                            .scaleEffect(3)
                    @unknown default:
                        Rectangle()
                            .foregroundColor(Color(.systemPurple))
                    }
                }
            }
            RoundedRectangle(cornerRadius: 15)
                .aspectRatio(0.8, contentMode: .fit)
                .foregroundColor(Color(.windowBackgroundColor))
                .padding()
            VStack {
                Spacer()
                Image(systemName: "touchid")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100)
                    .foregroundColor(Color(.systemRed))
                Spacer()
                Text("Touch ID Prompt")
                    .font(.largeTitle)
                    .redacted(reason: .placeholder)
                Spacer()
                VStack {
                    Text("Touch ID Detail prompt.Detail two.")
                        .font(.title3)
                    Text("Touch ID Detail prompt.Detail two.")
                        .font(.title3)
                }
                .redacted(reason: .placeholder)
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .frame(width: 275, height: 40, alignment: .center)
                    .foregroundColor(Color(.controlAccentColor))
                RoundedRectangle(cornerRadius: 10)
                    .frame(width: 275, height: 40, alignment: .center)
                    .foregroundColor(Color(.unemphasizedSelectedContentBackgroundColor))
            }.padding().padding()
        }
    }
    
}

#if DEBUG

struct CreateSecretView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            CreateSecretView(store: Preview.StoreModifiable(), showing: .constant(true))
            if #available(macOS 12.0, *) {
                AuthenticationView().environment(\.colorScheme, .dark)
                AuthenticationView().environment(\.colorScheme, .light)
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

#endif
