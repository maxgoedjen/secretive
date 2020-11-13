import Foundation
import SwiftUI

struct NoticeView: View {

    let text: String
    let severity: Severity
    let actionTitle: String?
    let action: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    public init(text: String, severity: NoticeView.Severity, actionTitle: String?, action: (() -> Void)?, secondaryActionTitle: String? = nil, secondaryAction: (() -> Void)? = nil) {
        self.text = text
        self.severity = severity
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        HStack {
            Text(text).bold()
            Spacer()
            if action != nil {
                if secondaryAction != nil {
                    Button(action: secondaryAction!) {
                        Text(secondaryActionTitle!)
                    }
                }
                Button(action: action!) {
                    Text(actionTitle!)
                }
            }
            }.padding().background(color)
    }

    var color: Color {
        switch severity {
        case .advisory:
            return Color.orange
        case .critical:
            return Color.red
        }
    }

}

extension NoticeView {

    enum Severity {
        case advisory, critical
    }

}

#if DEBUG

struct NoticeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoticeView(text: "Agent Not Running", severity: .advisory, actionTitle: "Run Setup") {
                print("OK")
            }
            NoticeView(text: "Critical Security Update Required", severity: .critical, actionTitle: "Update") {
                print("OK")
            }
        }
    }
}

#endif
