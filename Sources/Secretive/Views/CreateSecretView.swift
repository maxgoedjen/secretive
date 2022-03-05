import SwiftUI
import SecretKit

struct CreateSecretView<StoreType: SecretStoreModifiable>: View {

    @ObservedObject var store: StoreType
    @Binding var showing: Bool

    @State private var name = ""
    @State private var requiresAuthentication = true

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
                    if #available(macOS 12.0, *) {
                        ThumbnailPickerView(items: [
                            ThumbnailPickerView.Item(value: true, name: "Require Authentication", description: "You will be required to authenticate using Touch ID, Apple Watch, or password before each use.", thumbnail: AuthenticationView()),
                            ThumbnailPickerView.Item(value: false, name: "Notify",
                                                     description: "No authentication is required while your Mac is unlocked.",
                                                     thumbnail: NotificationView())
                        ], selection: $requiresAuthentication)
                    } else {
                        HStack {
                            VStack(spacing: 20) {
                                Picker("", selection: $requiresAuthentication) {
                                    Text("Requires Authentication (Biometrics or Password) before each use").tag(true)
                                    Text("Authentication not required when Mac is unlocked").tag(false)
                                }
                                .pickerStyle(RadioGroupPickerStyle())
                            }
                            Spacer()
                        }
                    }
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

struct ThumbnailPickerView<ValueType: Hashable>: View {

    private let items: [Item<ValueType>]
    @Binding var selection: ValueType

    init(items: [ThumbnailPickerView<ValueType>.Item<ValueType>], selection: Binding<ValueType>) {
        self.items = items
        _selection = selection
    }


    var body: some View {
        HStack {
            ForEach(items) { item in
                VStack {
                    item.thumbnail
                        .frame(width: 250, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(lineWidth: item.value == selection ? 5 : 0))
                        .foregroundColor(.accentColor)
                    Text(item.name)
                        .bold()
                    Text(item.description)
                }.onTapGesture {
                    selection = item.value
                }
            }
        }
    }

}

extension ThumbnailPickerView {

    struct Item<ValueType: Hashable>: Identifiable {
        let id = UUID()
        let value: ValueType
        let name: String
        let description: String
        let thumbnail: AnyView

        init<ViewType: View>(value: ValueType, name: String, description: String, thumbnail: ViewType) {
            self.value = value
            self.name = name
            self.description = description
            self.thumbnail = AnyView(thumbnail)
        }
    }

}

@available(macOS 12.0, *)
struct SystemBackgroundView: View {

    let anchor: UnitPoint

    var body: some View {
        if let mainScreen = NSScreen.main, let imageURL = NSWorkspace.shared.desktopImageURL(for: mainScreen) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty, .failure:
                    Rectangle()
                        .foregroundColor(Color(.systemPurple))
                case .success(let image):
                    image
                        .resizable()
                        .scaleEffect(3, anchor: anchor)
                        .clipped()
                @unknown default:
                    Rectangle()
                        .foregroundColor(Color(.systemPurple))
                }
            }
        } else {
            Rectangle()
                .foregroundColor(Color(.systemPurple))
        }
    }
}

@available(macOS 12.0, *)
struct AuthenticationView: View {

    var body: some View {
        ZStack {
            SystemBackgroundView(anchor: .center)
            GeometryReader { geometry in
                VStack {
                    Image(systemName: "touchid")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color(.systemRed))
                    Text("Touch ID Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .redacted(reason: .placeholder)
                    VStack {
                        Text("Touch ID Detail prompt.Detail two.")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        Text("Touch ID Detail prompt.Detail two.")
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    .redacted(reason: .placeholder)
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: geometry.size.width, height: 20, alignment: .center)
                        .foregroundColor(.accentColor)
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: geometry.size.width, height: 20, alignment: .center)
                        .foregroundColor(Color(.unemphasizedSelectedContentBackgroundColor))
                }
            }
            .padding()
            .frame(width: 150)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .foregroundStyle(.ultraThickMaterial)
            )
            .padding()

        }
    }

}

@available(macOS 12.0, *)
struct NotificationView: View {

    var body: some View {
        ZStack {
            SystemBackgroundView(anchor: .topTrailing)
            VStack {
                Rectangle()
                    .background(Color.clear)
                    .foregroundStyle(.thinMaterial)
                    .frame(height: 35)
                VStack {
                    HStack {
                        Spacer()
                        HStack {
                            Image(nsImage: NSApplication.shared.applicationIconImage)
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.primary)
                            VStack(alignment: .leading) {
                                Text("Secretive")
                                    .font(.title)
                                    .foregroundColor(.primary)
                                Text("Secretive wants to sign")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }.padding()
                        .redacted(reason: .placeholder)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .foregroundStyle(.ultraThickMaterial)
                        )
                    }
                    Spacer()
                }
                .padding()
            }
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
                NotificationView().environment(\.colorScheme, .dark)
                NotificationView().environment(\.colorScheme, .light)
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

#endif
