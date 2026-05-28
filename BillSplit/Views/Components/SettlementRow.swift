import SwiftUI

struct SettlementRow: View {
    let debt: DebtEntry
    let userNames: [String: String]
    let userAvatars: [String: String]
    let currentUserId: String
    let onMarkPaid: () -> Void
    @StateObject private var loc = LocaleManager.shared

    var body: some View {
        HStack {
            AvatarView(
                avatarUrl: isPayer ? userAvatars[debt.toUserId] : userAvatars[debt.fromUserId],
                displayName: isPayer ? (userNames[debt.toUserId] ?? "") : (userNames[debt.fromUserId] ?? ""),
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                if isPayer {
                    Text("\(loc.you) → \(userNames[debt.toUserId] ?? "...")")
                        .font(.subheadline)
                } else {
                    Text("\(userNames[debt.fromUserId] ?? "...") → \(loc.you)")
                        .font(.subheadline)
                }
                Text(CurrencySettings.shared.formatted(debt.amount))
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()

            if isPayer {
                Button(loc.markPaid) { onMarkPaid() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var isPayer: Bool { debt.fromUserId == currentUserId }
}
