import SwiftUI

struct InviteCodeCard: View {
    let code: String
    @StateObject private var loc = LocaleManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.inviteCode)
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
                Label(loc.copy, systemImage: "doc.on.doc")
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
