import SwiftUI

struct InviteCodeCard: View {
    let code: String

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("邀请码")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(code)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}
