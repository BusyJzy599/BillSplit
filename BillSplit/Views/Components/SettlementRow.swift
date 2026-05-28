import SwiftUI

struct SettlementRow: View {
    let debt: DebtEntry
    let userNames: [String: String]
    let currentUserId: String
    let onMarkPaid: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isPayer ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundColor(isPayer ? .red : .green)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                if isPayer {
                    Text("你 → \(userNames[debt.toUserId] ?? "...")")
                        .font(.subheadline)
                } else {
                    Text("\(userNames[debt.fromUserId] ?? "...") → 你")
                        .font(.subheadline)
                }
                Text(String(format: "¥%.2f", debt.amount))
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()

            if isPayer {
                Button("标记已还") { onMarkPaid() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var isPayer: Bool { debt.fromUserId == currentUserId }
}
