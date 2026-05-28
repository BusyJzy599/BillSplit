import SwiftUI

struct InviteCodeCard: View {
    let code: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("邀请码")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(code)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = code
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}
