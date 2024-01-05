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
                        Text("create_secret_title")
                            .font(.largeTitle)
                        Spacer()
                    }
                    HStack {
                        Text("create_secret_name_label")
                        TextField("create_secret_name_placeholder", text: $name)
                            .focusable()
                    }
                    ThumbnailPickerView(items: [
                        ThumbnailPickerView.Item(value: true, name: "create_secret_require_authentication_title", description: "create_secret_require_authentication_description", thumbnail: AuthenticationView()),
                        ThumbnailPickerView.Item(value: false, name: "create_secret_notify_title",
                                                 description: "create_secret_notify_description",
                                                 thumbnail: NotificationView())
                    ], selection: $requiresAuthentication)
                }
            }
            HStack {
                Spacer()
                Button("create_secret_cancel_button") {
                    showing = false
                }
                .keyboardShortcut(.cancelAction)
                Button("create_secret_create_button", action: save)
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
        HStack(alignment: .top) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 15) {
                    item.thumbnail
                        .frame(height: 200)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(lineWidth: item.value == selection ? 15 : 0))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.name)
                            .bold()
                        Text(item.description)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(width: 250)
                .onTapGesture {
                    withAnimation(.spring()) {
                        selection = item.value
                    }
                }
            }
            .padding(5)
        }
    }

}

extension ThumbnailPickerView {

    struct Item<ValueType: Hashable>: Identifiable {
        let id = UUID()
        let value: ValueType
        let name: LocalizedStringKey
        let description: LocalizedStringKey
        let thumbnail: AnyView

        init<ViewType: View>(value: ValueType, name: LocalizedStringKey, description: LocalizedStringKey, thumbnail: ViewType) {
            self.value = value
            self.name = name
            self.description = description
            self.thumbnail = AnyView(thumbnail)
        }
    }

}

@MainActor class SystemBackground: ObservableObject {

    static let shared = SystemBackground()
    @Published var image: NSImage?

    private init() {
        if let mainScreen = NSScreen.main, let imageURL = NSWorkspace.shared.desktopImageURL(for: mainScreen) {
            image = NSImage(contentsOf: imageURL)
        } else {
            image = nil
        }
    }

}

struct SystemBackgroundView: View {

    let anchor: UnitPoint

    var body: some View {
        if let image = SystemBackground.shared.image {
            Image(nsImage: image)
                .resizable()
                .scaleEffect(3, anchor: anchor)
                .clipped()
                .allowsHitTesting(false)
        } else {
            Rectangle()
                .foregroundColor(Color(.systemPurple))
        }
    }
}

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
                    Text(verbatim: "Touch ID Prompt")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .redacted(reason: .placeholder)
                    VStack {
                        Text(verbatim: "Touch ID Detail prompt.Detail two.")
                            .font(.caption2)
                            .foregroundColor(.primary)
                        Text(verbatim: "Touch ID Detail prompt.Detail two.")
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
                                Text(verbatim: "Secretive")
                                    .font(.title)
                                    .foregroundColor(.primary)
                                Text(verbatim: "Secretive wants to sign")
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
                AuthenticationView().environment(\.colorScheme, .dark)
                AuthenticationView().environment(\.colorScheme, .light)
                NotificationView().environment(\.colorScheme, .dark)
                NotificationView().environment(\.colorScheme, .light)
        }
    }
}

#endif
